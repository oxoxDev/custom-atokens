// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPMarket} from "@pendle/core-v2/contracts/interfaces/IPMarket.sol";

import {AToken, GPv2SafeERC20, IAaveIncentivesController, IERC20, IPool} from "@zerolendxyz/core-v3/contracts/protocol/tokenization/AToken.sol";
import {IMahaStakingRewards} from "../interfaces/IMahaStakingRewards.sol";

/// @notice ATokenPendlePT is a custom AToken for Pendle PT tokens
/// @dev This contract mainly restricts the minting of z0 tokens 1 day before expiry
contract ATokenPendlePT is AToken {
    using GPv2SafeERC20 for IERC20;

    IPMarket public market;
    uint256 public expiry;

    constructor(IPool pool) AToken(pool) {
        // Intentionally left blank
    }

    function getRevision() internal pure virtual override returns (uint256) {
        return 5;
    }

    function initialize(
        IPool initializingPool,
        address treasury,
        address underlyingAsset,
        IAaveIncentivesController incentivesController,
        uint8 aTokenDecimals,
        string calldata aTokenName,
        string calldata aTokenSymbol,
        bytes calldata params
    ) public virtual override initializer {
        super.initialize(
            initializingPool,
            treasury,
            underlyingAsset,
            incentivesController,
            aTokenDecimals,
            aTokenName,
            aTokenSymbol,
            params
        );

        // decode params
        address _market = abi.decode(params, (address));
        market = IPMarket(_market);
        expiry = market.expiry();
    }

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool returns (bool ret) {
        require(block.timestamp + 1 days < expiry, "EXPIRED"); // don't allow minting 1 day before expiry
        ret = _mintScaled(caller, onBehalfOf, amount, index);
    }
}