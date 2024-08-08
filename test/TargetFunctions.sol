
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
    }
    Counter counter;

    uint256 constant MAX_OFFERS = 5;

    /*//////////////////////////////////////////////////////////////////////////
                            SYSTEMCONFIG FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function systemConfig_updateMarket(string memory _marketPlaceName, address _tokenAddress, uint256 _tokenPerPoint, uint256 _tge, uint256 _settlementPeriod) public {
        hevm.prank(OWNER);
        try systemConfig.updateMarket(_marketPlaceName, _tokenAddress, _tokenPerPoint, _tge, _settlementPeriod) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  
    function systemConfig_updateMarketPlaceStatus(string memory _marketPlaceName, uint8 _status) public {
        hevm.prank(OWNER);
        try systemConfig.updateMarketPlaceStatus(_marketPlaceName, MarketPlaceStatus(_status)) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  

    /*//////////////////////////////////////////////////////////////////////////
                            PREMARKET FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    struct InvariantHelper {
        uint256 before_var;
        uint256 after_var;
    }

    // @fuzz-note consider limiting created offers to three (to five)
    function preMarktes_createOffer(CreateOfferParams calldata params) public {
        // if (counter.offerCount >= MAX_TRADING_ACCOUNT) return;
        // counter.offerCount += 1;


        hevm.prank(msg.sender);
        try preMarktes.createOffer(params) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  

    // // @fuzz-note remember to clamp the _offer addresses
    function preMarktes_createTaker(address _offer, uint256 _points) public {
        hevm.prank(msg.sender);
        try preMarktes.createTaker(_offer, _points) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }

    // @fuzz-note remember to clamp the _stock address and _collateralRate
    function preMarktes_listOffer(address _stock, uint256 _amount, uint256 _collateralRate) public {
        hevm.prank(msg.sender);
        try preMarktes.listOffer(_stock, _amount, _collateralRate) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  
    // @fuzz-note remember to clamp the _stock and _offer addresses
    function preMarktes_closeOffer(address _stock, address _offer) public {
        hevm.prank(msg.sender);
        try preMarktes.closeOffer(_stock, _offer) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  
    // @fuzz-note remember to clamp the _stock and _offer addresses
    function preMarktes_relistOffer(address _stock, address _offer) public {
        hevm.prank(msg.sender);
        try preMarktes.relistOffer(_stock, _offer) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  
    // @fuzz-note remember to clamp the _stock and _offer addresses
    function preMarktes_abortAskOffer(address _stock, address _offer) public {
        hevm.prank(msg.sender);
        try preMarktes.abortAskOffer(_stock, _offer) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  
    // @fuzz-note remember to clamp the _stock and _offer addresses
    function preMarktes_abortBidTaker(address _stock, address _offer) public {
        hevm.prank(msg.sender);
        try preMarktes.abortBidTaker(_stock, _offer) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  

    /*//////////////////////////////////////////////////////////////////////////
                            DELIVERYPLACE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/


    // @fuzz-note remember to clamp the _offer addresses
    function deliveryPlace_closeBidOffer(address _offer) public {
        hevm.prank(msg.sender);
        try deliveryPlace.closeBidOffer(_offer) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }

    // @fuzz-note remember to clamp the _stock addresses
    function deliveryPlace_closeBidTaker(address _stock) public {
        hevm.prank(msg.sender);
        try deliveryPlace.closeBidTaker(_stock) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  
    // @fuzz-note add the functionality for owner to call this function and the SettleAskMaker after the
    // settlement period has passed and the authority does call the function
    // @fuzz-note remember to clamp the _offer addresses
    function deliveryPlace_settleAskMaker(address _offer, uint256 _settledPoints, bool _useOwner) public {
        address caller = msg.sender;

        // after the settlement period has passed and _useOwner is true set OWNER to caller


        hevm.prank(caller);
        try deliveryPlace.settleAskMaker(_offer, _settledPoints) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }

    // @fuzz-note remember to clamp the _stock addresses
    function deliveryPlace_settleAskTaker(address _stock, uint256 _settledPoints, bool _useOwner) public {
        address caller = msg.sender;

        // after the settlement period has passed and _useOwner is true set OWNER to caller

        hevm.prank(caller);
        try deliveryPlace.settleAskTaker(_stock, _settledPoints) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                            TOKENMANAGER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    // @fuzz-note remember to clamp the _tokenAddress and _tokenBalanceType
    function tokenManager_withdraw(address _tokenAddress, uint8 _tokenBalanceType) public {
        hevm.prank(msg.sender);
        try tokenManager.withdraw(_tokenAddress, TokenBalanceType(_tokenBalanceType)) {} catch(bytes memory err) {
            _assertCustomErrorsAllowed(err, getAllowedErrors());
        }
    }
  
}


/*

getOfferAddresses() public view returns (address[] memory)
getStockAddresses() public view returns (address[] memory) 
getMakerAddresses() public view returns (address[] memory) 

*/