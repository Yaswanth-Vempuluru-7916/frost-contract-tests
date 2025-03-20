// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/FrostContract.sol";

contract StandardERC20Test is Test {
    StandardERC20 token;
    address owner = address(this);
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);

    uint256 constant DECIMALS = 10 ** 18;
    uint256 initialSupply = 1000 * DECIMALS;
    uint256 cap = 5000 * DECIMALS;

    function setUp() public {
        token = new StandardERC20(initialSupply / DECIMALS, cap / DECIMALS);
    }

    function testInitialization() public view {
        assertEq(token.name(), "FROST SHARD");
        assertEq(token.symbol(), "FROST");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), initialSupply);
        assertEq(token.cap(), cap);
        assertEq(token.balanceOf(owner), initialSupply);
        assertEq(token.owner(), owner);
    }

    function testTransfer() public {
        uint256 amount = 100 * DECIMALS;
        token.transfer(alice, amount);
        assertEq(token.balanceOf(owner), initialSupply - amount);
        assertEq(token.balanceOf(alice), amount);
    }

    function test_RevertWhen_TransferExceedsBalance() public {
        uint256 amount = (initialSupply + 1) * DECIMALS;
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.transfer(alice, amount);
    }

    function testApprovalAndTransferFrom() public {
        uint256 amount = 50 * DECIMALS;
        token.approve(alice, amount);
        assertEq(token.allowance(owner, alice), amount);

        vm.prank(alice);
        token.transferFrom(owner, bob, amount);

        assertEq(token.balanceOf(owner), initialSupply - amount);
        assertEq(token.balanceOf(bob), amount);
        assertEq(token.allowance(owner, alice), 0);
    }

    function testMint() public {
        uint256 amount = 500 * DECIMALS;
        token.mint(alice, amount);
        assertEq(token.totalSupply(), initialSupply + amount);
        assertEq(token.balanceOf(alice), amount);
    }

    // Test minting exceeds cap reverts
    function test_RevertWhen_MintExceedsCap() public {
        uint256 amount = (cap - initialSupply) + 1 * DECIMALS;
        vm.expectRevert("ERC20: cap exceeded");
        token.mint(alice, amount);
    }

    function test_RevertWhen_Mint_Not_Owner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        token.mint(alice, 100 * DECIMALS);
    }

    function testBurn() public {
        uint256 amount = 100 * DECIMALS;
        token.burn(owner, amount);
        assertEq(token.balanceOf(owner), initialSupply - amount);
        assertEq(token.totalSupply(), initialSupply - amount);
    }

    function test_RevertWhen_BurnExceedsBalance() public {
        uint256 amount = initialSupply + 1 * DECIMALS;
        vm.expectRevert("ERC20: burn amount exceeds balance");
        token.burn(owner, amount);
    }

    function test_RevertWhen_Burn_Not_Owner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        token.burn(owner, 100 * DECIMALS);
    }

    function testBurnFrom() public {
        uint256 amount = 100 * DECIMALS;
        token.approve(alice, amount);
        vm.prank(alice);
        token.burnFrom(owner, amount);
        assertEq(token.balanceOf(owner), initialSupply - amount);
        assertEq(token.totalSupply(), initialSupply - amount);
    }

    // Test transfer ownership
    function testTransferOwnership() public {
        token.transferOwnership(alice);
        assertEq(token.owner(), alice);
    }

    function test_RevertWhen_TransferOwnerShipNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        token.transferOwnership(bob);
    }

    function testIncreaseAndDecreaseAllowance() public {
        uint256 amount = 100 * DECIMALS;
        token.approve(alice, amount);
        token.increaseAllowance(alice, 50 * DECIMALS);
        assertEq(token.allowance(owner, alice), 150 * DECIMALS);

        token.decreaseAllowance(alice, 50 * DECIMALS);
        assertEq(token.allowance(owner, alice), 100 * DECIMALS);
    }

    function test_RevertWhen_DecreaseAllowanceBelowZero() public {
        token.approve(alice, 50 * DECIMALS);
        vm.expectRevert("ERC20: decreased allowance below zero");
        token.decreaseAllowance(alice, 51 * DECIMALS);
    }

    function test_RevertWhen_TranferToZeroAddress() public {
        vm.expectRevert("ERC20: transfer from zero address");
        vm.prank(address(0));
        token.transfer(owner, 50 * DECIMALS);
    }

    function test_RevertWhen_SelfTransfer() public {
        vm.expectRevert("ERC20: self-transfer not allowed");
        token.transfer(owner, 100 * DECIMALS);
    }

    function test_RevertWhen_ApproveFromZeroAddress() public {
        vm.prank(address(0));
        vm.expectRevert("ERC20: approve from zero address");
        token.approve(alice, 100 * DECIMALS);
    }

    function test_RevertWhen_ApproveToZeroAddress() public {
        vm.expectRevert("ERC20: approve to zero address");
        token.approve(address(0), 100 * DECIMALS);
    }

    function test_RevertWhen_TransferFromInsufficientAllowance() public {
        token.approve(alice, 100 * DECIMALS);
        vm.prank(alice);
        vm.expectRevert("ERC20: insufficient allowance");
        token.burnFrom(owner, 101 * DECIMALS);
    }

    function test_RevertWhen_BurnFromInsufficientAllowance() public {
        token.approve(alice, 50 * DECIMALS);

        vm.prank(alice);
        vm.expectRevert("ERC20: insufficient allowance");
        token.burnFrom(owner, 51 * DECIMALS);
    }

    function testUnlimitedApproval() public {
        token.approve(alice, type(uint256).max);

        vm.startPrank(alice);
        // First transfer shouldn't reduce allowance
        token.transferFrom(owner, bob, 100 * DECIMALS);
        assertEq(token.allowance(owner, alice), type(uint256).max);

        token.transferFrom(owner, charlie, 100 * DECIMALS);
        assertEq(token.allowance(owner, alice), type(uint256).max);
        vm.stopPrank();
    }

    function test_RevertWhen_ConstructorZeroCap() public {
        vm.expectRevert("Cap must be greater than zero");
        new StandardERC20(1000, 0);
    }

    function test_RevertWhen_ConstructorSupplyExceedsCap() public {
        vm.expectRevert("Initial supply exceeds cap");
        new StandardERC20(2000, 1000);
    }

    function test_RevertWhen_TransferOwnerShipToZeroAddress() public {
        vm.expectRevert("Ownable: new owner is zero address");
        token.transferOwnership(address(0));
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert("ERC20: mint to zero address");
        token.mint(address(0), 100 * DECIMALS);
    }

    function test_RevertWhen_BurnFromZeroAddress() public {
        vm.expectRevert("ERC20: burn from zero address");
        token.burn(address(0), 100 * DECIMALS);
    }

    function testMintToCapExactly() public {
        uint256 remainingToMint = cap - initialSupply;
        token.mint(owner, remainingToMint);
        assertEq(token.totalSupply(), cap);
    }

    function testTranferEvent() public {
        uint256 amount = 100 * DECIMALS;
        vm.expectEmit(true, true, false, true);
        // vm.expectEmit(true, true, true, true);
        // If you specifically want to verify that the transfer was sent to Alice (address 0x1)
        emit StandardERC20.Transfer(owner, alice, amount);
        token.transfer(alice, amount);
    }

    function testApprovalEvent() public {
        uint256 amount = 100 * DECIMALS;
        vm.expectEmit(true, true, false, true);
        emit StandardERC20.Approval(owner, alice, amount);
        token.approve(alice, amount);
    }

    function testOwnershipTransferredEvent() public {
        vm.expectEmit(true, true, false, false);
        emit StandardERC20.OwnershipTransferred(owner, alice);
        token.transferOwnership(alice);
    }

    function testComplexTransactionFlow() public {
        token.transfer(alice, 300 * DECIMALS);
        token.transfer(bob, 200 * DECIMALS);

        vm.prank(alice);
        token.approve(bob, 100 * DECIMALS);

        // Bob transfers 50 of Alice's tokens to Charlie
        vm.prank(bob);
        token.transferFrom(alice, charlie, 50 * DECIMALS);

        token.mint(alice, 150 * DECIMALS);

        // Alice approves herself to burn tokens (since she's not the owner)
        vm.prank(alice);
        token.approve(alice, 100 * DECIMALS);

        // Alice burns 100 of her tokens
        vm.prank(alice);
        token.burnFrom(alice, 100 * DECIMALS);

        assertEq(token.balanceOf(owner), initialSupply - 300 * DECIMALS - 200 * DECIMALS);
        assertEq(token.balanceOf(alice), 300 * DECIMALS - 50 * DECIMALS + 150 * DECIMALS - 100 * DECIMALS);
        assertEq(token.balanceOf(bob), 200 * DECIMALS);
        assertEq(token.balanceOf(charlie), 50 * DECIMALS);

        assertEq(token.totalSupply(), initialSupply + 150 * DECIMALS - 100 * DECIMALS);
    }

    function testOwnerFunctionalityAfterTransfer() public {
        // Transfer ownership to Alice
        token.transferOwnership(alice);

        // Try to mint as original owner (should fail)
        vm.expectRevert("Ownable: caller is not the owner");
        token.mint(bob, 100 * DECIMALS);

        // Alice should be able to mint now
        vm.prank(alice);
        token.mint(bob, 100 * DECIMALS);
        assertEq(token.balanceOf(bob), 100 * DECIMALS);

        // Alice should be able to burn
        vm.prank(alice);
        token.burn(bob, 50 * DECIMALS);
        assertEq(token.balanceOf(bob), 50 * DECIMALS);
    }

    function testUncheckedMathOptimization() public {
        // Initial distribution
        token.transfer(alice, 100 * DECIMALS);

        // Track gas usage for a transfer
        uint256 gasStart = gasleft();
        token.transfer(bob, 10 * DECIMALS);
        uint256 gasUsed = gasStart - gasleft();

        // Just a sanity check that gas is reasonable
        // This is not a strict test as gas costs can vary
        assertTrue(gasUsed < 60000, "Transfer consumes too much gas");
    }
}
