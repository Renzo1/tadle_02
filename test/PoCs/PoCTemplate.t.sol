
// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {TargetFunctions} from "../TargetFunctions.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";

import {OfferStatus, StockStatus, AbortOfferStatus, OfferType, StockType, OfferSettleType} from "../../src/storage/OfferStatus.sol";
import {IPerMarkets, OfferInfo, StockInfo, MakerInfo, CreateOfferParams} from "../../src/interfaces/IPerMarkets.sol";
import {TokenBalanceType, ITokenManager} from "../../src/interfaces/ITokenManager.sol";
import {ISystemConfig, ReferralInfo, MarketPlaceInfo, MarketPlaceStatus} from "../../src/interfaces/ISystemConfig.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {WETH9} from "../mocks/WETH9.sol";

contract PoCTemplate is Test, TargetFunctions, FoundryAsserts {
    address internal user;

    function setUp() public {
        setup();

        user = msg.sender;

        MockERC20(TOKENS[0]).mint(user, INITIAL_USD_BALANCE * (10 ** MockERC20(TOKENS[0]).decimals())); 
        MockERC20(TOKENS[1]).mint(user, INITIAL_USD_BALANCE * (10 ** MockERC20(TOKENS[1]).decimals())); 
        MockERC20(TOKENS[2]).mint(user, INITIAL_USD_BALANCE * (10 ** MockERC20(TOKENS[2]).decimals()));
        weth.mint(user, INITIAL_ETH_BALANCE * (10 ** weth.decimals()));
        hevm.deal(user, INITIAL_ETH_BALANCE * (10 ** weth.decimals())); // deal native eth

        vm.startPrank(user);
        USDC.approve(address(tokenManager), type(uint256).max);
        USDT.approve(address(tokenManager), type(uint256).max);
        UST.approve(address(tokenManager), type(uint256).max);
        weth.approve(address(tokenManager), type(uint256).max);
        PointTokenOne.approve(address(tokenManager), type(uint256).max);
        PointTokenTwo.approve(address(tokenManager), type(uint256).max);
        vm.stopPrank();
    }

    function testBobsSuperPowers() public {
        // TODO: Given any target function and foundry assert, test your results
    }
}
