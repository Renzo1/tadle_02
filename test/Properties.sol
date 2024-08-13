
// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {Setup} from "./Setup.sol";

import { Debugger } from "./utils/Debugger.sol";
import { EchidnaUtils } from "./utils/EchidnaUtils.sol";
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {MockERC20} from "./mocks/MockERC20.sol";
import {WETH9} from "./mocks/WETH9.sol";

import "../src/storage/OfferStatus.sol";
import "../src/interfaces/IPerMarkets.sol";
import "../src/interfaces/ISystemConfig.sol";
import "../src/interfaces/ITokenManager.sol";
import "../src/utils/Errors.sol";
import "src/utils/Related.sol";
import "src/utils/Rescuable.sol";
import "src/factory/ITadleFactory.sol";
import "src/interfaces/ICapitalPool.sol";
import "src/interfaces/IDeliveryPlace.sol";
import "../src/core/PreMarkets.sol";


import {MarketPlaceLibraries} from "../src/libraries/MarketPlaceLibraries.sol";
import {OfferLibraries} from "../src/libraries/OfferLibraries.sol";
import {Constants} from "../src/libraries/Constants.sol";


abstract contract Properties is Setup, Asserts {


    ////////////////// createOffer Properties ////////////////

    // @invariant trade Tax of an offer must always be greater than EACH_TRADE_TAX_DECIMAL_SCALER
    function crytic_tradeTaxOfOfferLessThanEACH_TRADE_TAX_DECIMAL_SCALER() public returns (bool) {
        bool returnData = true;
        address[] memory offerAddress = preMarktes.getOfferAddresses();

        for (uint256 i = 0; i < offerAddress.length; i++) {
            OfferInfo memory offerInfo = preMarktes.getOfferInfo(offerAddress[i]);
            if (offerInfo.tradeTax > Constants.EACH_TRADE_TAX_DECIMAL_SCALER) {
                returnData = false;
            }
        }
        return returnData;
    }

    struct MarketplaceOneOffersTrackerBefore {
        address[] marketplaceOneOffers;
        MarketPlaceInfo marketPlaceInfo;
    }
    MarketplaceOneOffersTrackerBefore marketplaceOneOffersTrackerBefore;

    struct MarketplaceOneOffersTrackerAfter {
        address[] marketplaceOneOffers;
        MarketPlaceInfo marketPlaceInfo;
    }

    // @invariant the offers for a market should not increase when the market status is not online
    function crytic_offersNotIncreaseWhenMarketIsNotOnline_One() public returns (bool) {
        bool returnData = true;
        uint256 id = 0;
        MarketplaceOneOffersTrackerAfter memory marketplaceOneOffersTrackerAfter;

        marketplaceOneOffersTrackerAfter.marketplaceOneOffers = getOffersForMarketplace(MARKETS[id]);
        marketplaceOneOffersTrackerAfter.marketPlaceInfo = systemConfig.getMarketPlaceInfo(MARKETS[id]);
        
        bool isMarketOnline = marketplaceOneOffersTrackerAfter.marketPlaceInfo.status == MarketPlaceStatus.Online;

        if (!isMarketOnline && marketplaceOneOffersTrackerBefore.marketplaceOneOffers.length != marketplaceOneOffersTrackerAfter.marketplaceOneOffers.length) {
            returnData = false;
        }

        marketplaceOneOffersTrackerBefore.marketplaceOneOffers = getOffersForMarketplace(MARKETS[id]);
        marketplaceOneOffersTrackerBefore.marketPlaceInfo = systemConfig.getMarketPlaceInfo(MARKETS[id]);
        return returnData;
    }


    // @invariant the total points for a market (some of points in a marketplaces offer) should not increase when 
    // the market status is not online


    // @invariant offerId should never decrease


    // @invariant no two stock Ids should be thesame


    // @invariant no two offer Ids should be the same


    // @invariant the OfferInfo for the originOffer of a makerInfo, should have thesame authority as the MakerInfo


    // @invariant OfferInfo and StockInfo with thesame offerId, should have thesame makerAddr


    // @invariant the settledPoints and settledPointTokenAmount should maintain a consistent relationship

    
    // @invariant the preOffer offerType of any Bid stock should be Ask if it the address isn't address(0x0) 
            
    
    
    // @invariant the preOffer offerType of any Ask offer should be Bid if it the address isn't address(0x0) 


    // @invariant for any offer, usedPoint should never be greater than points: offerInfo.usedPoints <= offerInfo.points


    // @invariant the offer type of an offer should not change once it is created


    // @invariant makerInfo.authority should not change after offer creation

    ////////////////// createTaker Properties ////////////////
    
    // @invariant no two stock Ids should be the same
    
    
    // @invariant no listed offer should have a zero offerInfo.amount 
    
    
    ////////////////// listOffer Properties ////////////////
    
    // @invariant the marketplace for every listed offer should be online


    // @invariant collateral rate shouldn't never change


    // @invariant makerInfo.originOffer should never change


    // @invariant in turbo mode: the collateral rate of a list offer, should be equal to the collateralRate of the originOffer


    // @invariant in turbo mode: the abortOfferStatus of the originalOffer should change to SubOfferListed after listing an offer

    // @invariant makerInfo offerSettleType should never change once created and set



    ////////////////// Other Properties in PreMarket ////////////////
    
    // @invariant for all offers if offerInfo.usedPoints == 0, offerInfo.offerStatus should be OfferStatus.Virgin
    
    
    // @invariant sum of all initial deposit and collateral that haven't been settled/closed/aborted should be <= raw CP balance for a specific token

    
    // @invariant sum of users tadle account balance should be <= raw CP balance for a specific token



    ////////////////// Other Properties in DeliveryPlace ////////////////

    // @invariant Bid offer status should never change from any other status but virgin to Canceled or Settled


    // @invariant Bid offer status should never change from any other status but Canceled or Settled to virgin


    // @invariant users should receive the correct amount of tokens (factor rounding directing, usedPoints and amount)


    // @precondition for any offer offerInfo.points >= offerInfo.usedPoints @invariant


    // @invariant takers should receive depositAmount of the stockInfo (factoring rounding direction)


    // @invariant a stock status should not be Finished if its associated order is not Settled


    // @invariant a stock should never change from initialized to Finished while the associated offer status is not set to settled


    // @invariant for any offer the offerInfo.usedPoints <= offerInfo.settledPoints


    // @invariant sum of the points for all the stocks for a particular offer (common preOffer) should be equal to the offer's used points
    

    // @invariant for every stock the stockType must be the opposite of the associated preOffer offerType


    // @invariant the offerInfo.usedPoints should not change when the offerInfo.status is settled


    // @invariant a stock status should never change from Finished to any other state


    // @invariant an offer status should never change from settled to any other state


    // @invariant for any offer if the offerStatus is not settled, the settledPoints should be zero

    // @invariant for all stock: stock status should not change from any state back to initialize

    // @invariant for any stock: the stockInfo.points should never change

    // @invariant offerInfo.maker should never change

    // @invariant settlementPeriod should always be greater than tge for all marketplaces

    // @invariant offer collateralRate should always be greater than 10_000 (100%)
}
