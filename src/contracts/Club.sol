// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "../interface/IClub.sol";

contract Club is IClub, ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 public merkleRoot;

    mapping(address => uint256) private _alreadyMinted;
    mapping(uint256 => Club) private clubs;
    mapping(bytes32 => Member) public clubMembers;

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    /// @inheritdoc IClub
    function claimClub(
        uint256 amount,
        uint256 maxAmount,
        bytes32[] calldata merkleProof
    ) external {
        address sender = _msgSender();
        if (amount > (maxAmount - _alreadyMinted[sender])) revert NoMintLeft();
        if (!_verify(merkleProof, sender, maxAmount)) revert InvalidProof();

        _alreadyMinted[sender] += amount;

        for (uint256 i = 1; i <= amount; i++) {
            _mint(sender, totalSupply());
        }
    }

    /// @inheritdoc IClub
    function requestJoin(
        uint256 clubId,
        address nft,
        uint256 tokenId
    ) external nonReentrant {
        address owner = _msgSender();
        // Check club exists
        if (!_clubExists(clubId)) revert ClubNotFound();
        // Check NFT ownership
        if (!_isNFTOwner(nft, tokenId, owner)) revert NoNFTOwner();
        bytes32 memberHash = _getMemberHash(nft, tokenId);
        // Check NFT is already a member
        if (_memberExists(memberHash)) revert MemberNotAvailable();
        // Check if member has sent another join request
        if (EnumerableSet.contains(clubs[clubId].joinRequests, memberHash))
            revert RequestAlreadySent();

        Member memory member = Member(nft, tokenId, owner, 0);
        clubMembers[memberHash] = member;
        EnumerableSet.add(clubs[clubId].joinRequests, memberHash);

        emit JoinRequest(clubId, member);
    }

    /// @inheritdoc IClub
    function acceptJoin(
        uint256 clubId,
        address nft,
        uint256 tokenId
    ) external nonReentrant onlyClubOwner(clubId) {
        // Check club exists
        if (!_clubExists(clubId)) revert ClubNotFound();

        bytes32 memberHash = _getMemberHash(nft, tokenId);
        Member storage member = clubMembers[memberHash];
        Club storage club = clubs[clubId];

        if (!_hasRequestedJoin(clubId, memberHash)) revert NoJoinRequest();

        uint256 membersQuantity = EnumerableSet.length(clubs[clubId].members);
        if (membersQuantity >= club.maxCapacity) revert ClubFull();

        // Transfer NFT
        ERC721(nft).transferFrom(member.owner, address(this), tokenId);

        member.joinTimestamp = block.timestamp;

        EnumerableSet.add(clubs[clubId].members, memberHash);
        EnumerableSet.remove(clubs[clubId].joinRequests, memberHash);

        emit JoinRequestAccepted(clubId, member);
    }

    /// @inheritdoc IClub
    function rejectJoin(
        uint256 clubId,
        address nft,
        uint256 tokenId
    ) external onlyClubOwner(clubId) {
        // Check club exists
        if (!_clubExists(clubId)) revert ClubNotFound();

        bytes32 memberHash = _getMemberHash(nft, tokenId);

        EnumerableSet.remove(clubs[clubId].joinRequests, memberHash);

        emit JoinRequestRejected(clubId, nft, tokenId);
    }

    /// @inheritdoc IClub
    function cancelJoin(
        uint256 clubId,
        address nft,
        uint256 tokenId
    ) external {
        // Check club exists
        if (!_clubExists(clubId)) revert ClubNotFound();

        address owner = _msgSender();
        bytes32 memberHash = _getMemberHash(nft, tokenId);

        // Check NFT ownership
        if (!_isNFTOwner(nft, tokenId, owner)) revert NoNFTOwner();

        // Check request exists
        if (!_hasRequestedJoin(clubId, memberHash)) revert NoJoinRequest();

        // Remove from Set
        EnumerableSet.remove(clubs[clubId].joinRequests, memberHash);

        // Emit Event
        emit JoinRequestCanceled(clubId, nft, tokenId);
    }

    /// @inheritdoc IClub
    function leaveClub(
        uint256 clubId,
        address nft,
        uint256 tokenId
    ) external {
        // Check club exists
        if (!_clubExists(clubId)) revert ClubNotFound();

        address owner = _msgSender();
        bytes32 memberHash = _getMemberHash(nft, tokenId);

        // Check NFT ownership
        if (!_isNFTOwner(nft, tokenId, owner)) revert NoNFTOwner();

        // Check Club member
        if (!_isClubMember(clubId, memberHash)) revert NotMember();

        Member storage member = clubMembers[memberHash];
        Club storage club = clubs[clubId];

        // Check member has been in club more than minimun time
        uint256 leaveAfterTimestamp = member.joinTimestamp +
            club.minDuration *
            1 days;

        if (leaveAfterTimestamp < block.timestamp) revert NotMinTime();

        EnumerableSet.remove(club.members, memberHash);

        emit MemberLeft(clubId, nft, tokenId);
    }

    /// @inheritdoc IClub
    function claimRewards(uint256 clubId, Member calldata member) external {}

    /// @inheritdoc IClub
    function claimRewards(uint256 clubId) external {}

    function setMerkleProof(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    // PUBLIC

    function alreadyMinted(address addr) public view returns (uint256) {
        return _alreadyMinted[addr];
    }

    function clubMinDuration(uint256 clubId) public view returns (uint16) {
        return clubs[clubId].minDuration;
    }

    function clubOwnerShare(uint256 clubId) public view returns (uint16) {
        return clubs[clubId].ownersShare;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable)
        returns (bool)
    {
        return
            interfaceId == type(IClub).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // PROTECTED

    function _mint(address to, uint256 clubId) internal override {
        super._mint(to, clubId);
        Club storage club = clubs[clubId];
        club.maxCapacity = 30; // 30 Members
        club.minDuration = 30; // 30 Days
        club.ownersShare = 4000; // 40%

        // Deploy `PaymentSplitter` contract
        address[] memory payees = new address[](1);
        uint256[] memory shares = new uint256[](1);
        payees[0] = _msgSender();
        shares[0] = club.ownersShare;

        PaymentSplitter paymentSplitter = new PaymentSplitter(payees, shares);
        club.paymentReceiver = address(paymentSplitter);
    }

    function _getMemberHash(address nft, uint256 tokenId)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(nft, tokenId));
    }

    function _memberExists(bytes32 memberHash) internal view returns (bool) {
        return clubMembers[memberHash].owner != address(0);
    }

    function _clubExists(uint256 clubId) private view returns (bool) {
        return ownerOf(clubId) != address(0);
    }

    // PRIVATE

    function _verify(
        bytes32[] calldata merkleProof,
        address sender,
        uint256 maxAmount
    ) private view returns (bool) {
        bytes32 leaf = keccak256(
            abi.encodePacked(sender, maxAmount.toString())
        );
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }

    function _isClubMember(uint256 clubId, bytes32 memberHash)
        private
        view
        returns (bool)
    {
        return EnumerableSet.contains(clubs[clubId].members, memberHash);
    }

    function _hasRequestedJoin(uint256 clubId, bytes32 memberHash)
        private
        view
        returns (bool)
    {
        return EnumerableSet.contains(clubs[clubId].joinRequests, memberHash);
    }

    function _isNFTOwner(
        address nft,
        uint256 tokenId,
        address owner
    ) private view returns (bool) {
        return ERC721(nft).ownerOf(tokenId) == owner;
    }

    // MODIFIER

    modifier onlyClubOwner(uint256 clubId) {
        if (ownerOf(clubId) != _msgSender()) revert NoClubOwner();
        _;
    }
}

/*
 * 88888888ba  88      a8P  88
 * 88      "8b 88    ,88'   88
 * 88      ,8P 88  ,88"     88
 * 88aaaaaa8P' 88,d88'      88
 * 88""""88'   8888"88,     88
 * 88    `8b   88P   Y8b    88
 * 88     `8b  88     "88,  88
 * 88      `8b 88       Y8b 88888888888
 *
 * IClub.sol
 *
 * MIT License
 * ===========
 *
 * Copyright (c) 2022 Rumble League Studios Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 */
