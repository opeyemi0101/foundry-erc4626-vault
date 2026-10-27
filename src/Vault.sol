// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Vault is ERC4626 {
    constructor(IERC20 asset_) ERC4626(asset_) ERC20("Vault Share", "vSHARE") {}

    function _decimalsOffset() internal pure override returns (uint8) {
    return 6;
}
}