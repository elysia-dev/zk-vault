// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Vault.sol";
import "../src/MockUSDT.sol";

string constant FROM_BINANCE_ID = "93260646";

contract VaultTest is Test {
    Vault vault;
    MockUSDT mockUsdt;
    uint256 amount = 5 * 1e6;

    uint256 privateKey = 123456789;
    address notary = vm.addr(privateKey);
    // generate a new address
    address recipientAddress = makeAddr("recipientAddress");

    function setUp() public {
        console2.log("Notary address: %s", notary);

        mockUsdt = new MockUSDT();

        vault = new Vault(address(mockUsdt), notary);
        mockUsdt.mint(address(vault), 100 * 1e6);
    }

    function testEnroll() public {
        vault.enroll(FROM_BINANCE_ID, recipientAddress, amount);
        bytes32 enrollId = vault.recipientToEnrollId(recipientAddress);

        (string memory from_binance_id_, address recipient_, uint256 amount_, bool claimed_) =
            vault.enrollments(enrollId);
        assertEq(from_binance_id_, FROM_BINANCE_ID);
        assertEq(recipient_, recipientAddress);
        assertEq(amount_, amount);
        assertEq(claimed_, false);
    }

    function testEnrollTooMuch() public {
        uint256 amount = 11 * 1e6; // 11 USDT with 6 decimals, exceeds the 10 USDT limit
        vm.expectRevert("Amount exceeds 10 USDT limit");
        vault.enroll(FROM_BINANCE_ID, recipientAddress, amount);
    }

    function testClaim() public {
        uint256 amount = 5 * 1e6; // 8 USDT with 6 decimals
        // new user
        vault.enroll(FROM_BINANCE_ID, recipientAddress, amount);
        bytes32 enrollId = vault.recipientToEnrollId(recipientAddress);

        // make message hash (same as Vault.claim)
        bytes32 messageHash = keccak256(abi.encodePacked(enrollId, amount));

        // sign message with notary's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);

        console2.log("v: %s", v);
        console2.logBytes32(r);
        console2.logBytes32(s);

        uint256 recipientBalanceBefore = mockUsdt.balanceOf(recipientAddress);
        vault.claim(enrollId, amount, v, r, s);
        uint256 recipientBalanceAfter = mockUsdt.balanceOf(recipientAddress);
        assertEq(recipientBalanceAfter - recipientBalanceBefore, amount, "Token transfer did not happen correctly");
    }
}
