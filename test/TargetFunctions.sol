
// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "./BeforeAfter.sol";
import {Properties} from "./Properties.sol";
import {vm} from "@chimera/Hevm.sol";

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


abstract contract TargetFunctions is BaseTargetFunctions, Properties, BeforeAfter {
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////////////////
                            AUXILIARY FUNCTIONS AND MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    function getAllowedErrors() public pure returns (bytes4[] memory) {

        bytes4[] memory allowedErrors = new bytes4[](43);

        allowedErrors[0] = Errors.ContractIsNotDeployed.selector;
        allowedErrors[1] = Errors.NotEnoughMsgValue.selector;
        allowedErrors[2] = Errors.ZeroAddress.selector;
        allowedErrors[3] = Errors.AmountIsZero.selector;
        allowedErrors[4] = Errors.Unauthorized.selector;
        allowedErrors[5] = Related.CallerIsNotRelatedContracts.selector;
        allowedErrors[6] = Related.CallerIsNotDeliveryPlace.selector;
        allowedErrors[7] = Rescuable.TransferFailed.selector;
        allowedErrors[8] = Rescuable.AlreadyInitialized.selector;
        allowedErrors[9] = ITadleFactory.UnDepoloyedProxyAdmin.selector;
        allowedErrors[10] = ICapitalPool.ApproveFailed.selector;
        allowedErrors[11] = IDeliveryPlace.InvalidOfferType.selector;
        allowedErrors[12] = IDeliveryPlace.InvalidOfferStatus.selector;
        allowedErrors[13] = IDeliveryPlace.InvalidStockStatus.selector;
        allowedErrors[14] = IDeliveryPlace.InvaildMarketPlaceStatus.selector;
        allowedErrors[15] = IDeliveryPlace.InvalidStock.selector;
        allowedErrors[16] = IDeliveryPlace.InvalidStockType.selector;
        allowedErrors[17] = IDeliveryPlace.InsufficientRemainingPoints.selector;
        allowedErrors[18] = IDeliveryPlace.InvalidPoints.selector;
        allowedErrors[19] = IDeliveryPlace.FixedRatioUnsupported.selector;
        allowedErrors[20] = IPerMarkets.InvalidEachTradeTaxRate.selector;
        allowedErrors[21] = IPerMarkets.InvalidCollateralRate.selector;
        allowedErrors[22] = IPerMarkets.InvalidOfferAccount.selector;
        allowedErrors[23] = IPerMarkets.MakerAlreadyExist.selector;
        allowedErrors[24] = IPerMarkets.OfferAlreadyExist.selector;
        allowedErrors[25] = IPerMarkets.StockAlreadyExist.selector;
        allowedErrors[26] = IPerMarkets.InvalidOffer.selector;
        allowedErrors[27] = IPerMarkets.InvalidOfferType.selector;
        allowedErrors[28] = IPerMarkets.InvalidStockType.selector;
        allowedErrors[29] = IPerMarkets.InvalidOfferStatus.selector;
        allowedErrors[30] = IPerMarkets.InvalidAbortOfferStatus.selector;
        allowedErrors[31] = IPerMarkets.InvalidStockStatus.selector;
        allowedErrors[32] = IPerMarkets.NotEnoughPoints.selector;
        allowedErrors[33] = ISystemConfig.InvalidReferrer.selector;
        allowedErrors[34] = ISystemConfig.InvalidRate.selector;
        allowedErrors[35] = ISystemConfig.InvalidReferrerRate.selector;
        allowedErrors[36] = ISystemConfig.InvalidTotalRate.selector;
        allowedErrors[37] = ISystemConfig.InvalidPlatformFeeRate.selector;
        allowedErrors[38] = ISystemConfig.MarketPlaceAlreadyInitialized.selector;
        allowedErrors[39] = ISystemConfig.MarketPlaceNotOnline.selector;
        allowedErrors[40] = ITokenManager.TokenIsNotWhiteListed.selector;
        allowedErrors[41] = ITadleFactory.LogicAddrIsNotContract.selector;
        allowedErrors[42] = ITadleFactory.CallerIsNotGuardian.selector;

        return allowedErrors;
    }


    ///////// DoS Catcher /////////
    event UnexpectedCustomError(bytes);
    function _assertCustomErrorsAllowed(bytes memory err, bytes4[] memory allowedErrors) private {
        bool allowed;
        bytes4 errorSelector = bytes4(err);
        uint256 allowedErrorsLength = allowedErrors.length;

        for (uint256 i; i < allowedErrorsLength;) {
            if (errorSelector == allowedErrors[i]) {
                allowed = true;
                break;
            }
            unchecked {++i;}
        }

        if(!allowed) {
            emit UnexpectedCustomError(err);
            assert(false);
        }
    }

    struct Counter{
        uint256 offerCount;
        uint256 stockCount;
        uint256 marketPlaceCount;
    }
    Counter counter;

    uint256 constant MAX_OFFERS = 5;
    uint256 constant MAX_STOCKS = 20;
    uint256 constant MARKETPLACESUPDATE_DIVISOR = 50;





    /*//////////////////////////////////////////////////////////////////////////
                            SYSTEMCONFIG FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
   // @fuzz-note set the market status to online in setup() and never call updateMarketPlaceStatus
    // - set a counter that allow this target function to be called once after Max count (e.g. 1000) calls
    // - return if count is not modulo by divisor is not zero
    // - iterate through the markets:
    // - if: settlementPeriod has passed && tge is set{
    // -    call SystemConfig::updateMarket to set marketPlaceInfo with reasonably random values
    // -    _marketPlaceName: for index i == 0 select our market name
    // -    _tge: blocktimestamp + random number of days (1 day - 180 months)
    // -    _settlementPeriod is blocktimestamp + tge + random number of hours (24 - 72 hours) - according to the doc
    // -    tokenPerPoint: random uint128 value. remember to cast to 256
    // -    tokenAddress: address of i index

    struct ConfigHelper {
        MarketPlaceInfo marketPlaceInfo;
        string _marketPlaceName;
        address _tokenAddress;
        uint256 tokenPerPoint;
    }

    function systemConfig_updateMarket(uint128 _tokenPerPoint, uint256 _tge, uint256 _settlementPeriod) public {
        if (counter.marketPlaceCount % MARKETPLACESUPDATE_DIVISOR != 0) return;
        counter.marketPlaceCount += 1;

        ConfigHelper memory params;

        
        for(uint256 i = 0; i < MARKETS.length; i++) {
            params.marketPlaceInfo = systemConfig.getMarketPlaceInfo(MARKETS[i]);
            params._marketPlaceName = i == 0 ? "Backpack" : "Frontpouch";
            params._tokenAddress = POINTTOKENS[i];
            params.tokenPerPoint = uint256(_tokenPerPoint) + 1_000_000;
            _tge = block.timestamp + EchidnaUtils.clampBetween(_tge, 1 days, 180 days);
            _settlementPeriod = block.timestamp + _tge + EchidnaUtils.clampBetween(_settlementPeriod, 24 hours, 72 hours);
            
            if (params.marketPlaceInfo.tge != 0 && block.timestamp > params.marketPlaceInfo.settlementPeriod) {
                hevm.prank(OWNER);
                try systemConfig.updateMarket(params._marketPlaceName, params._tokenAddress, _tokenPerPoint, _tge, _settlementPeriod) {
                } catch(bytes memory err) {
                    _assertCustomErrorsAllowed(err, getAllowedErrors());
                }
            }
        }
    }


    /*//////////////////////////////////////////////////////////////////////////
                            PREMARKET FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    

    struct InvariantHelper {
        uint256 before_var;
        uint256 after_var;
    }

    struct CreateOfferHelper {
        uint256 ethAmount;


        uint256 points;
        uint256 amount;
        uint256 collateralRate;
        uint256 eachTradeTax;
        OfferType offerType;
        OfferSettleType offerSettleType;
    }



    // ✅@fuzz-note consider limiting created offers to concentrate the fuzzer
    // ✅@fuzz-note edit source code to return the new offerAddress, stockAddress, and makerAddress
    // @fuzz-note for calculating exact transferAmount deposited or refunded as in contract - OfferLibraries.getDepositAmount()
    function preMarktes_createOffer(
        bool marketPlaceOneId, 
        uint8 tokenIndex, 
        uint256 points, 
        uint256 amount, 
        uint256 collateralRate, 
        uint256 eachTradeTax,
        OfferType offerType,
        OfferSettleType offerSettleType
    ) public {
        // constrain the created offers to MAX_OFFERS, but when no offer has a status of Virgin, reset the offerCount to 0
        if (!getOneOfferWithVirginStatus()) counter.offerCount = 0;
        if (counter.offerCount >= MAX_OFFERS) return;
        counter.offerCount += 1;

        CreateOfferParams memory params;
        CreateOfferHelper memory helper;

        params.marketPlace = marketPlaceOneId ? MARKETS[0] :  MARKETS[1];
        params.tokenAddress = TOKENS[EchidnaUtils.clampBetween(uint256(tokenIndex), 0, TOKENS.length - 1)];
        params.points = points;
        params.amount = EchidnaUtils.clampBetween(amount, 0, IERC20(params.tokenAddress).balanceOf(msg.sender));
        params.collateralRate = EchidnaUtils.clampBetween(collateralRate, 0, Constants.COLLATERAL_RATE_DECIMAL_SCALER - 1);
        params.eachTradeTax = EchidnaUtils.clampBetween(eachTradeTax, 0, Constants.EACH_TRADE_TAX_DECIMAL_SCALER);
        params.offerType = offerType;
        params.offerSettleType = offerSettleType;



        if(params.tokenAddress == address(weth)){
            params.amount = EchidnaUtils.clampBetween(amount, 0, msg.sender.balance);
            helper.ethAmount = params.amount;
        }


        hevm.prank(msg.sender);
        try preMarktes.createOffer{value: helper.ethAmount}(params) returns (PreMarktes.ReturnAddresses memory returnAddresses) {
            // return ReturnAddresses(makerAddr, offerAddr,stockAddr);
            /// Arrange

            /// Invariants
            // @invariant offers should not be backed by points - revert if the collateral token is point token

            // @invariant users should not be able to list offers on marketPlaces that are not online

            // @invariant the users raw balance should decrease by param.amount

            // @invariant if param.token is ERC20 and mode is not turbo: the users raw ERC20 balance should decrease by created offer amount (factor rounding direction)

            // @invariant if param.token is weth and mode is not turbo: the users raw ETH balance should decrease by created offer amount (factor rounding direction)

            // @invariant for bid offerType, the amount deducted from the user's balance is == specified amount

        } catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }

    struct CreateTakerHelper {
        address offer;
        address[] offerAddresses;
    }
  

    // @fuzz-note clamp the _offer addresses
    // @fuzz-note edit source code to return the new stockAddress
    function preMarktes_createTaker(uint256 _offerId, uint256 _points) public {
        // constrain the created stocks to MAX_STOCKS, but when no stock has a status of Initialized, reset the stockCount to 0
        if (!getOneStockWithInitializedStatus()) counter.stockCount = 0;
        if (counter.stockCount >= MAX_STOCKS) return;
        counter.stockCount += 1;

        CreateTakerHelper memory helper;

        // get offer Array
        helper.offerAddresses = preMarktes.getOfferAddresses();
        helper.offer = helper.offerAddresses[EchidnaUtils.clampBetween(_offerId, 0, helper.offerAddresses.length - 1)];


        hevm.prank(msg.sender);
        try preMarktes.createTaker(helper.offer, _points) returns (address stockAddr){
            /// Arrange

            /// Invariants
            // @invariant the target offer usedPoints should increase by the _points param after every createTaker() Tx

            // @invariant if the status of the target off is not Virgin, this createTaker() should revert

            // @invariant users should always pay transaction fee

            // @invariant the users raw balance should decrease by transferAmount (depositAmount + platformFee + tradeTax)

            // @invariant users should not be able to operate on other users accounts

            // @invariant users should not be able to list offers on marketPlaces that are not online

            // @invariant the new stock points should be set to points

            // @invariant the tradeTax should be sent to the right authority
            // In turbo mode: originalOffer maker | In protected mode: directed offer maker

            // @invariant if param.token is weth: the users raw ETH balance should decrease by created stock amount + fees (factor rounding direction)


            // @invariant if param.token is ERC20: the users raw ERC20 balance should decrease by created stock amount + fees(factor rounding direction)


        } catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }

    struct ListOfferHelper{
        address stock;
        address[] stockAddresses;
        uint256 collateralRate;
        uint256 amount;
        uint256 ethAmount;
        StockInfo stockInfo;
        MakerInfo makerInfo;
    }

    // @fuzz-note remember to clamp the _stock address and _collateralRate
    // @fuzz-note edit source code to return the new offerAddress
    function preMarktes_listOffer(uint256 _stockId, uint256 _amount, uint256 collateralRate) public {

        ListOfferHelper memory helper;

        
        // get stock Array
        helper.stockAddresses = preMarktes.getStockAddresses();
        helper.stock = helper.stockAddresses[EchidnaUtils.clampBetween(_stockId, 0, helper.stockAddresses.length - 1)];
        helper.collateralRate = EchidnaUtils.clampBetween(collateralRate, 0, Constants.COLLATERAL_RATE_DECIMAL_SCALER - 1);

        helper.stockInfo = preMarktes.getStockInfo(helper.stock);
        helper.makerInfo = preMarktes.getMakerInfo(helper.stockInfo.maker);

        helper.amount = EchidnaUtils.clampBetween(_amount, 0, IERC20(helper.makerInfo.tokenAddress).balanceOf(msg.sender));


        if(helper.makerInfo.tokenAddress == address(weth)){
            helper.amount = EchidnaUtils.clampBetween(helper.amount, 0, msg.sender.balance);
            helper.ethAmount = helper.amount;
        }

        hevm.prank(msg.sender);
        try preMarktes.listOffer{value: helper.ethAmount}(helper.stock, helper.amount, helper.collateralRate) returns (address offerAddr) {
            /// Arrange

            /// Invariants

            // @invariant users should not be able to list offers on marketPlaces that are not online

            // @invariant no offer should be listed multiple times -- if target stock already has an associated offer with the same Id
            // this should revert

            // @invariant the stockType for the target stock when this function is called must be Bid


            // @invariant in turbo mode: caller balance should not change

            // @invariant the new offer id should be the same as the target stock id

            // @invariant in protected mode: caller tadle balance should decrease by amount

            // @invariant the amount of points for the new offer should be equal to the points in the target stock

            // @invariant listOffer should revert if stockInfo.offer is not address(0)

            // @invariant the stockInfo.id should not be equal to any existing offer.id

            // @invariant the id of the new offer, should not match the id of any existing offer

            } catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  
    struct CloseOfferHelper{
        address[] stockAddresses;
        address[] offerAddresses;
        address stock;
        address offer;
        uint256 collateralRate;
    }

    // @fuzz-note remember to clamp the _stock and _offer addresses
    function preMarktes_closeOffer(uint256 _stockId, uint256 _offerId) public {
        CloseOfferHelper memory helper;

        // get stock and offer Array
        helper.stockAddresses = preMarktes.getStockAddresses();
        helper.offerAddresses = preMarktes.getOfferAddresses();

        helper.stock = helper.stockAddresses[EchidnaUtils.clampBetween(_stockId, 0, helper.stockAddresses.length - 1)];
        helper.offer = helper.offerAddresses[EchidnaUtils.clampBetween(_offerId, 0, helper.offerAddresses.length - 1)];

        hevm.prank(msg.sender);
        try preMarktes.closeOffer(helper.stock, helper.offer) {
            /// Arrange

            /// Invariants
            // @invariant if offerInfo.usedPoints is > 0, closeOffer should revert

            // @invariant users should not be able to close offer in marketplaces that aren't online

            // @invariant makers should receive the correct amount of collateral owed to them, factoring usedPoints, initial deposit and rounding direction

            // @invariant when a turbo offer is closed, the authority's tadle balance (for the collateral token) should not change
            // collateral token type is held in associated makerInfo.tokenAddress

            // @invariant for offer authority: getInitialDepositForOffer() = △ CT tadle balance + convertToCT(offerInfo.usedPoints)

        } catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  
      
    struct RelistOfferHelper{
        address[] stockAddresses;
        address[] offerAddresses;
        address stock;
        address offer;
        uint256 collateralRate;
    }

    // @fuzz-note remember to clamp the _stock and _offer addresses
    function preMarktes_relistOffer(uint256 _stockId, uint256 _offerId) public {
        RelistOfferHelper memory helper;

        // get stock and offer Array
        helper.stockAddresses = preMarktes.getStockAddresses();
        helper.offerAddresses = preMarktes.getOfferAddresses();

        helper.stock = helper.stockAddresses[EchidnaUtils.clampBetween(_stockId, 0, helper.stockAddresses.length - 1)];
        helper.offer = helper.offerAddresses[EchidnaUtils.clampBetween(_offerId, 0, helper.offerAddresses.length - 1)];

        hevm.prank(msg.sender);
        try preMarktes.relistOffer(helper.stock, helper.offer) {
            /// Arrange

            /// Invariants
            // @invariant you can't relist an Offer if its marketplace is not online
        
            // @invariant when an offer is closed and relisted, it should be collateralized with the exact same refunded amount

            // @invariant in protected mode: caller tadle balance should decrease by depositAmount (refunded amount)

            // @invariant if param.token is ERC20 and mode is not turbo: the users raw ERC20 balance should decrease by created offer amount (factor rounding direction)
            
            // @invariant if param.token is weth and mode is not turbo: the users raw ETH balance should decrease by created offer amount (factor rounding direction)

            
        } catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  
          
    struct AbortAskOfferHelper{
        address[] stockAddresses;
        address[] offerAddresses;
        address stock;
        address offer;
        uint256 collateralRate;
    }

    // @fuzz-note remember to clamp the _stock and _offer addresses
    function preMarktes_abortAskOffer(uint256 _stockId, uint256 _offerId) public {
        AbortAskOfferHelper memory helper;

        // get stock and offer Array
        helper.stockAddresses = preMarktes.getStockAddresses();
        helper.offerAddresses = preMarktes.getOfferAddresses();

        helper.stock = helper.stockAddresses[EchidnaUtils.clampBetween(_stockId, 0, helper.stockAddresses.length - 1)];
        helper.offer = helper.offerAddresses[EchidnaUtils.clampBetween(_offerId, 0, helper.offerAddresses.length - 1)];

        hevm.prank(msg.sender);
        try preMarktes.abortAskOffer(helper.stock, helper.offer) {
            /// Arrange

            /// Invariants
            // @invariant this function should fail is the stock and offer aren't related
        
            // @invariant this function should revert if the target offer usedPoint is > 0

            // @invariant can only abort offers in a market that is online

            // @invariant makers should receive the correct amount of collateral owed to them, factoring usedPoints, initial deposit and rounding direction

            // @invariant if offerInfo.usedPoints is 0 and caller is maker (_offer == makerInfo.originOffer ||
            // makerInfo.offerSettleType == OfferSettleType.Protected), the maker should receive same amount of the collateral tokens deposited

            // @invariant taker should not be able to abort the same offer more than once

            // @invariant taker should not be able to abort offer after it has been settled

            // @invariant for offer authority: getInitialDepositForOffer() = △ CT tadle balance + convertToCT(offerInfo.usedPoints)

        } catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  

              
    struct AbortBidTakerHelper{
        address[] stockAddresses;
        address[] offerAddresses;
        address stock;
        address offer;
        uint256 collateralRate;
    }

    // @fuzz-note remember to clamp the _stock and _offer addresses
    function preMarktes_abortBidTaker(uint256 _stockId, uint256 _offerId) public {
        RelistOfferHelper memory helper;

        // get stock and offer Array
        helper.stockAddresses = preMarktes.getStockAddresses();
        helper.offerAddresses = preMarktes.getOfferAddresses();

        helper.stock = helper.stockAddresses[EchidnaUtils.clampBetween(_stockId, 0, helper.stockAddresses.length - 1)];
        helper.offer = helper.offerAddresses[EchidnaUtils.clampBetween(_offerId, 0, helper.offerAddresses.length - 1)];

        hevm.prank(msg.sender);
        try preMarktes.abortBidTaker(helper.stock, helper.offer) {
            /// Arrange

            /// Invariants
            // @invariant a stock stock.preOffer field should never change

            // @invariant users should receive the same amount of collateral tokens deposited (factoring platformFee, tradeTax, and rounding direction)
        
            // @invariant taker should not be able to abort the same bid more than once

            // @invariant taker should not be able to abort bid after it has been settled

            // @invariant for stock authority: getInitialDepositForStock() = △ CT tadle balance

        } catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  

    /*//////////////////////////////////////////////////////////////////////////
                            DELIVERYPLACE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    struct DeliveryPlaceHelper{
        address[] stockAddresses;
        address[] offerAddresses;
        address stock;
        address offer;
        uint256 collateralRate;
    }

    // @fuzz-note remember to clamp the _offer addresses
    function deliveryPlace_closeBidOffer(uint256 _offerId) public {
        DeliveryPlaceHelper memory helper;

        helper.offerAddresses = preMarktes.getOfferAddresses();
        helper.offer = helper.offerAddresses[EchidnaUtils.clampBetween(_offerId, 0, helper.offerAddresses.length - 1)];


        hevm.prank(msg.sender);
        try deliveryPlace.closeBidOffer(helper.offer) {
            /// Arrange

            /// Invariants
            // @invariant every point holder should be able to redeem their points available points

            // @invariant for offer authority: getInitialDepositForOffer() = △ CT tadle balance + convertToCT(getReceivedPT())

            // @invariant if (offerInfo.settledPointTokenAmount > 0 && (offerSettleType == OfferSettleType.Protected ||
            // stockInfo.offer == address(0x0)){ this function should revert}
        
        } catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }

    // @fuzz-note remember to clamp the _stock addresses
    // @fuzz-note add convertPointTokenToCollateralToken and convertCollateralTokenToPointToken helper functions in setup.sol
    function deliveryPlace_closeBidTaker(uint256 _stockId) public {
        DeliveryPlaceHelper memory helper;

        helper.stockAddresses = preMarktes.getStockAddresses();
        helper.stock = helper.stockAddresses[EchidnaUtils.clampBetween(_stockId, 0, helper.stockAddresses.length - 1)];


        hevm.prank(msg.sender);
        try deliveryPlace.closeBidTaker(helper.stock) {
            /// Arrange

            /// Invariants
            // @invariant every point holder should be able to redeem their points available points

            // @invariant takers should receive depositAmount of the stockInfo (factoring rounding direction, usedPoints and amount)
        
            // @invariant if a bid related offer's usedPoints < points, this function should not revert (all conditions been correct and used points)

            // @invariant for stock authority: getInitialDepositForStock() = △ CT tadle balance + convertToCT(△ PT tadle balance)

            // @invariant after settlement the taker stock status should change to Finished
                
        } catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  
    // @fuzz-note add the functionality for owner to call this function and the SettleAskMaker after the
    // settlement period has passed and the authority does call the function
    // @fuzz-note remember to clamp the _offer addresses
    function deliveryPlace_settleAskMaker(uint256 _offerId, uint256 _settledPoints) public {

        DeliveryPlaceHelper memory helper;

        helper.offerAddresses = preMarktes.getOfferAddresses();
        helper.offer = helper.offerAddresses[EchidnaUtils.clampBetween(_offerId, 0, helper.offerAddresses.length - 1)];


        hevm.prank(msg.sender);
        try deliveryPlace.settleAskMaker(helper.offer, _settledPoints) {
            /// Arrange

            /// Invariants
            // @invariant every point holder should be able to redeem their points available points

            // @invariant every point holder should receive point tokens proportional to their available points when maker settles their offers

            // @invariant after settlement, the maker should receive the correct amount of collateral tokens

            // @invariant after DeliveryPlace settlement process, taker should receive the correct amount of point tokens
            // and collateral tokens (in case of partial settlement)

            // @invariant for offer authority: getInitialDepositForOffer() = △ CT tadle balance + convertPointsToPT(unsettledPoints)
        
            // @invariant after settlement the offer settledPoints should increase by the amount of points they settled

            // @invariant after settlement the offer settledPointTokenAmount should increase by the point tokens sent to stock authority account

            // @invariant revert if _settledPoints > offerInfo.usedPoints - offerInfo.settledPoints

            // @invariant if target offer settledPoints > 0 and _settledPoints > 0, this function should revert

            // @invariant for any offer: if the offerStatus is virgin, the usedPoints should be 0

            // @invariant settleAskMaker should revert if target offer settledPoints > 0 and param _settledPoints > 0
            
            // @invariant Bid settling can't happen before the end of settlementPeriod for a the marketplace

        } catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }

    // @fuzz-note remember to clamp the _stock addresses
    function deliveryPlace_settleAskTaker(uint256 _stockId, uint256 _settledPoints) public {
        DeliveryPlaceHelper memory helper;

        helper.stockAddresses = preMarktes.getStockAddresses();
        helper.stock = helper.stockAddresses[EchidnaUtils.clampBetween(_stockId, 0, helper.stockAddresses.length - 1)];


        hevm.prank(msg.sender);
        try deliveryPlace.settleAskTaker(helper.stock, _settledPoints) {
            /// Arrange

            /// Invariants
            // @invariant every point holder should be able to redeem their points available points

            // @invariant every point holder should receive point tokens proportional to their available points when maker settles their offers 
        
            // @invariant after DeliveryPlace settlement process, taker should receive the correct amount of point tokens
            // and collateral tokens (in case of partial settlement)

            // @invariant for stock authority: getInitialDepositForStock = △ CT tadle balance + convertToCT(unsettledPoints)

            // @invariant after settlement the offer settledPoints should increase by the amount of points they settled

            // @invariant if taker settles all the points in their stock, their balance for their collateral token
            // should increase by their initial collateral

            // @invariant maker pointToken tadle balance increase == taker raw pointToken balance decrease

            // @invariant ask settling shouldn't happen after _marketPlaceInfo.tge + _marketPlaceInfo.settlementPeriod

            // @invariant Bid settling can't happen before the end of settlementPeriod for a the marketplace


        } catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                            TOKENMANAGER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    struct TokenManagerHelper{
        address tokenAddress;
    }

    // @fuzz-note remember to clamp the _tokenAddress and _tokenBalanceType
    function tokenManager_withdraw(uint8 tokenAddressId, uint8 _tokenBalanceType) public {

        TokenManagerHelper memory helper;

        helper.tokenAddress = ALL_TOKENS[EchidnaUtils.clampBetween(uint256(tokenAddressId), 0, ALL_TOKENS.length - 1)];

        hevm.prank(msg.sender);
        try tokenManager.withdraw(helper.tokenAddress, TokenBalanceType(_tokenBalanceType)) {
            /// Arrange

            /// Invariants
            // @invariant change in users raw balance should equal availableAmount (factoring rounding direction)

            // @invariant users _tokenAddress raw balance should increase by claimableAmount (factoring rounding direction)

            
        } catch(bytes memory err) {
            // @invariant if user's is claimAbleAmount > 0, and this function should not revert

            
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  
}


