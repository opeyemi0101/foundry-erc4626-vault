// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Vault} from "../../src/Vault.sol";

contract VaultTest is Test {
    Vault public vault;
    ERC20Mock public asset;
 
     // user 
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    uint256 public constant DEPOSIT = 100 ether;

    function setUp() public {
        asset = new ERC20Mock();
        vault = new Vault(IERC20(address(asset)));
        asset.mint(user1, 1000 ether);
        asset.mint(user2, 1000 ether);
     }

    function _deposit(address user, uint256 amount) internal returns (uint256 shares) {
        vm.startPrank(user);
        asset.approve(address(vault), amount);
        shares = vault.deposit(amount, user);
        vm.stopPrank();
    }

    function testFirstDepositIsOneToOne() public {
        uint256 shares = _deposit(user1, DEPOSIT);

        assertEq(shares, DEPOSIT);
        assertEq(vault.balanceOf(user1), DEPOSIT);
        assertEq(vault.totalAssets(), DEPOSIT);
    }

    function testWithdrawReturnsDeposit() public {
        _deposit(user1, DEPOSIT);

        vm.prank(user1);
        vault.withdraw(DEPOSIT, user1, user1);

        assertEq(asset.balanceOf(user1), 1000 ether);
        assertEq(vault.balanceOf(user1), 0);
    }

    function testYieldRaisesShareValue() public {
        uint256 shares = _deposit(user1, DEPOSIT);

        // simulate yield by sending extra assets straight to the vault
        asset.mint(address(vault), 50 ether);

        assertApproxEqAbs(vault.convertToAssets(shares), 150 ether, 10);
    }

    function testLaterDepositorGetsFewerShares() public {
        _deposit(user1, DEPOSIT);
        asset.mint(address(vault), DEPOSIT); // share price doubles

        uint256 shares2 = _deposit(user2, DEPOSIT);

        assertApproxEqAbs(shares2, 50 ether, 10);
        assertLt(shares2, DEPOSIT);
    }

    function testRedeemAfterYield() public {
        uint256 shares = _deposit(user1, DEPOSIT);
        asset.mint(address(vault), 50 ether);

        vm.prank(user1);
        uint256 assetsOut = vault.redeem(shares, user1, user1);

        assertApproxEqAbs(assetsOut, 150 ether, 10);
        assertEq(vault.balanceOf(user1), 0);
    }

   function testInflationAttackIsNotProfitable() public {
    address attacker = makeAddr("attacker");
    address victim = makeAddr("victim");
    uint256 donation = 10 ether;

    asset.mint(attacker, 1 + donation);
    asset.mint(victim, donation);

    // 1. attacker becomes the first depositor with 1 wei
    vm.startPrank(attacker);
    asset.approve(address(vault), type(uint256).max);
    vault.deposit(1, attacker);
    // 2. attacker donates directly to inflate the share price
    assertTrue(asset.transfer(address(vault), donation));
    vm.stopPrank();

    // 3. victim deposits
    vm.startPrank(victim);
    asset.approve(address(vault), type(uint256).max);
    uint256 victimShares = vault.deposit(donation, victim);
    vm.stopPrank();

    // what the victim's shares are worth right now
    uint256 victimValue = vault.convertToAssets(victimShares);
    uint256 victimLoss = donation > victimValue ? donation - victimValue : 0;

    // 4. attacker redeems everything
    uint256 attackerShares = vault.balanceOf(attacker);
    vm.prank(attacker);
    uint256 attackerOut = vault.redeem(attackerShares, attacker, attacker);

    uint256 attackerSpent = 1 + donation;
    uint256 attackerLoss = attackerSpent > attackerOut ? attackerSpent - attackerOut : 0;

    console.log("victim shares: ", victimShares);
    console.log("victim loss: ", victimLoss);
    console.log("attacker loss: ", attackerLoss);

    // the attacker must not profit
    assertLt(attackerOut, attackerSpent);
    // the attack must cost the attacker at least as much as it costs the victim
    assertGe(attackerLoss, victimLoss);
}
}