// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StableCoin} from "./StableCoin.sol";

// Add collateral -> Only ETH
// redeem collateral
// Check health factor
// mint stablecoin
// burn stablecoin
// Liquidate -> liquidate the user unhealthy position
// get account information -> amount of stablecoin minted and amount of collaterall deposited
contract Engine {
    error Engine__TransactionFailed();
    error Engine__InvalidAmount();
    error Engine__InvalidAmountOfCollateralToRedeem(uint256 currentBalance);
    error Engine__BreaksHealthFactor(uint256 accountHealthFactor);

    AggregatorV3Interface private s_dataFeed;
    StableCoin private immutable i_stableCoin;

    uint256 private constant MIN_HEALTH_FACTOR = 150;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;

    mapping(address => uint256) private s_depositedCollateral;
    mapping(address => uint256) private s_stablecoinAmountMinted;

    constructor(address priceFeedAddress, address stableCoinAddress) {
        s_dataFeed = AggregatorV3Interface(priceFeedAddress);
        i_stableCoin = StableCoin(stableCoinAddress);
    }

    // check how to handle the stored amount if in eth or usd
    function addCollateral() external payable {
        if (msg.value == 0) {
            revert Engine__InvalidAmount();
        }

        s_depositedCollateral[msg.sender] = msg.value;
    }

    // check that do nots break health factor
    function redeemCollateral(uint256 _amountToReedem) external {
        if (_amountToReedem == 0) {
            revert Engine__InvalidAmount();
        }

        if (s_depositedCollateral[msg.sender] < _amountToReedem) {
            revert Engine__InvalidAmountOfCollateralToRedeem(s_depositedCollateral[msg.sender]);
        }

        s_depositedCollateral[msg.sender] -= _amountToReedem;

        (bool success,) = payable(msg.sender).call{value: _amountToReedem}("");
        if (!success) {
            revert Engine__TransactionFailed();
        }
    }

    // check they have enough collateral deposited to mint that amount
    function mintStableCoin(uint256 _amountToMint) external {
        s_stablecoinAmountMinted[msg.sender] += _amountToMint;
        i_stableCoin.mint(msg.sender, _amountToMint);
    }

    function burnStableCoin(uint256 _amountToBurn) external {
        s_stablecoinAmountMinted[msg.sender] -= _amountToBurn;
        i_stableCoin.burn(_amountToBurn);
    }

    // External user may be able to check other user health factor and liquidate them
    // by paying their debt and gaining a % of benefit like 10%
    function liquidate() external {}

    function revertIfHealthFactorIsBroken(address _account) internal view {
        uint256 accountHealthFactor = checkHealthFactor(_account);
        if (accountHealthFactor < MIN_HEALTH_FACTOR) {
            revert Engine__BreaksHealthFactor(accountHealthFactor);
        }
    }

    function checkHealthFactor(address _account) internal view returns (uint256) {
        (uint256 collateralDeposited, uint256 stableCoinMinted) = getAccountInformation(_account);
        uint256 ethInUsdDeposited = getEthBalanceInUsd(collateralDeposited);
        return (ethInUsdDeposited / stableCoinMinted) * 100;
    }

    function getAccountInformation(address _account) public view returns (uint256, uint256) {
        uint256 collateralDeposited = s_depositedCollateral[_account];
        uint256 stableCoinMinted = s_stablecoinAmountMinted[_account];

        return (collateralDeposited, stableCoinMinted);
    }

    function getEthBalanceInUsd(uint256 _ethAmount) internal view returns (uint256) {
        (
            /* uint80 roundId */
            ,
            int256 currentEthPrice,
            /* uint256 startedAt */
            ,
            /* uint256 updatedAt */
            ,
            /* uint80 answeredInRound */
        ) = s_dataFeed.latestRoundData();

        return ((uint256(currentEthPrice) * ADDITIONAL_FEED_PRECISION) * _ethAmount) / PRECISION;
    }
}
