// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPMarket} from "@pendle/core-v2/contracts/interfaces/IPMarket.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AToken, IAaveIncentivesController, IPool} from "@zerolendxyz/core-v3/contracts/protocol/tokenization/AToken.sol";

/// @notice ATokenPendleLP is a custom AToken for Pendle LP tokens
/// @dev This contract is used to collect the PENDLE rewards from the Pendle Market contract
/// @dev This contract restricts the minting of z0 tokens 1 day before expiry
contract ATokenPendleLP is AToken {
    using SafeERC20 for IERC20;

    IPMarket public market;
    IERC20 public pendle;
    uint256 public expiry;
    address public emissionReceiver;

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
        (address _market, address _emissionReceiver, address _pendle) = abi
            .decode(params, (address, address, address));
        emissionReceiver = _emissionReceiver;

        market = IPMarket(_market);
        expiry = market.expiry();

        // give approvals
        pendle = IERC20(_pendle);
        _ensureApprove(_pendle, type(uint256).max);
    }

    function mint(
        address caller,
        address onBehalfOf,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool returns (bool ret) {
        require(block.timestamp + 1 days < expiry, "EXPIRED"); // don't allow minting 1 day before expiry jsut for safety purposes
        ret = _mintScaled(caller, onBehalfOf, amount, index);
        refreshRewards();
    }

    function burn(
        address from,
        address receiverOfUnderlying,
        uint256 amount,
        uint256 index
    ) external virtual override onlyPool {
        refreshRewards();
        _burnScaled(from, receiverOfUnderlying, amount, index);
        if (receiverOfUnderlying != address(this)) {
            IERC20(_underlyingAsset).safeTransfer(receiverOfUnderlying, amount);
        }
    }

    function refreshRewards() public {
        market.redeemRewards(address(this));
    }

    /// @dev Used to set the emissions manager
    function setEmissionsManager(
        address _emissionReceiver
    ) public onlyPoolAdmin {
        _ensureApprove(address(pendle), 0);
        emissionReceiver = _emissionReceiver;
        _ensureApprove(address(pendle), type(uint256).max);
    }

    function _ensureApprove(address _token, uint _amt) internal {
        if (IERC20(_token).allowance(address(this), address(emissionReceiver)) < _amt) {
            IERC20(_token).forceApprove(address(emissionReceiver), type(uint).max);
        }
    }
}
