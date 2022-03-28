// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IClubNFT {
    /// @notice revert if club reaches maximum capacity
    error ClubFull();

    /// @notice revert if msg.sender is not part of the club
    error NotMember();

    /// @notice revert if club is not found
    error ClubNotFound();

    /// @notice revert if join club request is already present
    error RequestAlreadySent();

    /// @notice revert if member tries to leave club before minimum time
    error NotMinTime();

    /// @notice emitted when a club is created
    /// @param clubId ID of the club created
    event ClubClaimed(uint256 clubId);

    /// @notice emitted when a new join request is created
    /// @param clubId ID of the club requested to join
    /// @param tokenId ID of the NFT used to request join
    event JoinRequest(uint256 clubId, uint256 tokenId);

    /// @notice emitted when join request is accepted
    /// @param clubId ID of the club requested to join
    /// @param tokenId ID of the NFT used to request join
    event JoinRequestAccepted(uint256 clubId, uint256 tokenId);

    /// @notice emitted when join request is rejected
    /// @param clubId ID of the club requested to join
    /// @param tokenId ID of the NFT used to request join
    event JoinRequestRejected(uint256 clubId, uint256 tokenId);

    /// @notice emitted when a member leaves the club
    /// @param clubId ID of the club left
    /// @param tokenId ID of the NFT that left the club
    event ClubLeft(uint256 clubId, uint256 tokenId);

    struct Club {
        /// @notice array of token IDs
        uint256[] members;
        /// @notice
        uint256[] joinRequests;
        /// @notice all payments must be send to the payment receiver
        address paymentReceiver;
        /// @notice minimum duration of days a member must stay
        uint16 minDuration;
        /// @notice owner's share of the earnings.
        /// @dev percentage with 2 decimals, multiplied by 100
        ///      Ex: 100% = 10000 / 35.85% = 3585
        uint16 ownersShare;
    }

    /// @notice Create a club, this will mint a club NFT
    /// @param amount number of clubs wanted to be claimed
    /// @param maxAmount maximum number of clubs allowed to be claimed
    /// @param merkleProof array of node hashes used to generate proof
    /// @dev Emits a ClubClaimed event
    /// @dev the node leaf is created from hash of the concatenation of
    ///      the msg.sender and the maximum amount
    function claimClub(
        uint256 amount,
        uint256 maxAmount,
        bytes32[] calldata merkleProof
    ) external;

    /// @notice To join the club, a NFT owner or a borrower can call this function.
    /// @dev Emits a JoinRequest event.
    /// @param clubId ID of the club.
    /// @param tokenId ID of the NFT that is going to join the club
    function requestJoin(uint256 clubId, uint256 tokenId) external;

    /// @notice Accept join request
    /// @dev Emits a JoinRequestAccepted event
    /// @param clubId ID of the club.
    /// @param tokenId ID of the NFT to determinate join request
    function acceptJoin(uint256 clubId, uint256 tokenId) external;

    /// @notice Reject join request
    /// @dev Emits a JoinRequestRejected event
    /// @param clubId ID of the club.
    /// @param tokenId ID of the NFT to determinate join request
    function rejectJoin(uint256 clubId, uint256 tokenId) external;

    /// @notice Leave the Club
    /// @dev Emits a ClubLeft event
    /// @param clubId ID of the club.
    /// @param tokenId ID of the NFT that will leave the club
    function leaveClub(uint256 clubId, uint256 tokenId) external;

    /// @notice claim club rewards for members
    /// @param clubId ID of the club.
    /// @param tokenId ID of the NFT used to claim rewards
    function claimRewards(uint256 clubId, uint256 tokenId) external;

    /// @notice claim club rewards for club owners
    /// @param clubId ID of the club.
    function claimRewards(uint256 clubId) external;
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
 * IClubNFT.sol
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
