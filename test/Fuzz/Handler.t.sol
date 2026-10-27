// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Vault} from "../../src/Vault.sol";

contract Handler is Test {
    Vault public vault;
    ERC20Mock public asset;

    address[] public users; // 5 users to fuzz with
    uint256 public constant MAX_DEPOSIT = 1_000_000e18;
    uint256 public constant MAX_YIELD = 100_000e18;

    // ghost variables: the Handler's own record of asset flow
    uint256 public ghostDeposited;
    uint256 public ghostYield;
    uint256 public ghostWithdrawn;

    constructor(Vault _vault, ERC20Mock _asset) {
        vault = _vault;
        asset = _asset;
        for (uint256 i = 0; i < 5; i++) {
            users.push(address(uint160(0x1000 + i)));
        }
    }

    function deposit(uint256 userSeed, uint256 amount) public {
        address user = _pickUser(userSeed);
        amount = bound(amount, 1e18, MAX_DEPOSIT);

        asset.mint(user, amount);
        vm.startPrank(user);
        asset.approve(address(vault), amount);
        vault.deposit(amount, user);
        vm.stopPrank();

        ghostDeposited += amount;
    }

    function withdraw(uint256 userSeed, uint256 amount) public {
        address user = _pickUser(userSeed);
        uint256 maxAssets = vault.maxWithdraw(user);
        if (maxAssets == 0) {
            return;
        }
        amount = bound(amount, 1, maxAssets);

        vm.prank(user);
        vault.withdraw(amount, user, user);

        ghostWithdrawn += amount;
    }

    function redeem(uint256 userSeed, uint256 shares) public {
        address user = _pickUser(userSeed);
        uint256 userShares = vault.balanceOf(user);
        if (userShares == 0) {
            return;
        }
        shares = bound(shares, 1, userShares);

        vm.prank(user);
        uint256 assetsOut = vault.redeem(shares, user, user);

        ghostWithdrawn += assetsOut;
    }

    /// @dev simulates the vault earning yield
    function donateYield(uint256 amount) public {
        amount = bound(amount, 1, MAX_YIELD);
        asset.mint(address(vault), amount);
        ghostYield += amount;
    }

    function _pickUser(uint256 seed) internal view returns (address) {
        return users[seed % users.length];
    }

    function getUsers() public view returns (address[] memory) {
        return users;
    }
}