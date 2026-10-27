// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {Vault} from "../../src/Vault.sol";
import {Handler} from "./Handler.t.sol";

contract VaultInvariantTest is StdInvariant, Test {
    Vault public vault;
    ERC20Mock public asset;
    Handler public handler;

    function setUp() public {
        asset = new ERC20Mock();
        vault = new Vault(IERC20(address(asset)));
        handler = new Handler(vault, asset);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = Handler.deposit.selector;
        selectors[1] = Handler.withdraw.selector;
        selectors[2] = Handler.redeem.selector;
        selectors[3] = Handler.donateYield.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// Every asset in the vault is explained by a deposit or a yield donation, minus withdrawals.
    function invariant_assetsAreConserved() public view {
        uint256 expected = handler.ghostDeposited() + handler.ghostYield() - handler.ghostWithdrawn();
        assertEq(asset.balanceOf(address(vault)), expected);
    }

    /// All outstanding shares, redeemed at once, can never be worth more than the vault holds.
    function invariant_vaultIsSolvent() public view {
        assertLe(vault.convertToAssets(vault.totalSupply()), vault.totalAssets());
    }

    /// Share supply equals the sum of every user's shares.
    function invariant_sharesMatchTotalSupply() public view {
        address[] memory users = handler.getUsers();
        uint256 sum;
        for (uint256 i = 0; i < users.length; i++) {
            sum += vault.balanceOf(users[i]);
        }
        assertEq(sum, vault.totalSupply());
    }

    /// totalAssets reports the vault's real token balance.
    function invariant_totalAssetsMatchesBalance() public view {
        assertEq(vault.totalAssets(), asset.balanceOf(address(vault)));
    }
}