// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IPaymentReceiver {
    /// @notice emitted when a payee withdraws assets
    /// @param to receiver of the assets
    /// @param tokens tokens distribued
    /// @param amount of tokens distribued
    event PaymentReleased(address to, address[] tokens, uint256[] amount);

    /// @notice emitted when a token is added
    /// @param token address of the new token
    event NewToken(address token);

    /// @notice emitted when a new payee is added
    /// @param payee address of the new payee
    event PayeeAdded(address payee);

    /// @notice emitted when a payee is removed
    /// @param payee address of the payee removed
    event PayeeRemoved(address payee);

    /// @notice Add a new payee
    /// @param payee address of the payee 
    function addPayee(address payee) external;

    /// @notice Remove a payee
    /// @param payee address of the payee
    function removePayee(address payee) external;

    /// @notice Add a new token to keep track of
    /// @param token address of the new token
    function addToken(address token) external;

    /// @notice release assets to a payee
    /// @param payee address of the payee
    function release(address payee) external;
}