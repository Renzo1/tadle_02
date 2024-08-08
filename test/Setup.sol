
// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseSetup} from "@chimera/BaseSetup.sol";

import {Test, console2} from "forge-std/Test.sol";
import {SystemConfig} from "../src/core/SystemConfig.sol";
import {CapitalPool} from "../src/core/CapitalPool.sol";
import {TokenManager} from "../src/core/TokenManager.sol";
import {PreMarktes} from "../src/core/PreMarkets.sol";
import {DeliveryPlace} from "../src/core/DeliveryPlace.sol";
import {TadleFactory} from "../src/factory/TadleFactory.sol";

import {OfferStatus, StockStatus, AbortOfferStatus, OfferType, StockType, OfferSettleType} from "../src/storage/OfferStatus.sol";
import {IPerMarkets, OfferInfo, StockInfo, MakerInfo, CreateOfferParams} from "../src/interfaces/IPerMarkets.sol";
import {TokenBalanceType, ITokenManager} from "../src/interfaces/ITokenManager.sol";

import {GenerateAddress} from "../src/libraries/GenerateAddress.sol";

import {MockERC20Token} from "./mocks/MockERC20Token.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {WETH9} from "./mocks/WETH9.sol";
import {UpgradeableProxy} from "../src/proxy/UpgradeableProxy.sol";


// import "src/storage/DeliveryPlaceStorage.sol";
// import "src/utils/Rescuable.sol";
// import "src/storage/UpgradeableStorage.sol";
// import "src/storage/TokenManagerStorage.sol";
// import "src/storage/CapitalPoolStorage.sol";
// import "src/storage/SystemConfigStorage.sol";
// import "src/interfaces/IDeliveryPlace.sol";
// import "src/utils/Errors.sol";
// import "src/utils/Related.sol";
// import "src/interfaces/ISystemConfig.sol";
// import "src/interfaces/IWrappedNativeToken.sol";
// import "src/factory/ITadleFactory.sol";
// import "src/storage/PerMarketsStorage.sol";
// import "src/interfaces/ICapitalPool.sol";


interface IHevm {
  // Set block.timestamp to newTimestamp
  function warp(uint256 newTimestamp) external;

  // Sets block.number
  function roll(uint256 newNumber) external;

  // Sets the eth balance of usr to amt
  function deal(address usr, uint256 amt) external;

  // Gets address for a given private key
  function addr(uint256 privateKey) external returns (address addr);

  // Performs the next smart contract call with specified `msg.sender`
  function prank(address newSender) external;

}


abstract contract Setup is BaseSetup {

  IHevm hevm = IHevm(address(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D));

  /*//////////////////////////////////////////////////////////////////////////
                                    VARIABLES
  //////////////////////////////////////////////////////////////////////////*/

  uint256 basePlatformFeeRate = 5_000; // 0.5%
  uint256 baseReferralRate = 300_000; // 30%

  bytes4 private constant INITIALIZE_OWNERSHIP_SELECTOR = bytes4(keccak256(bytes("initializeOwnership(address)")));


  ///////////////////// TOKENS AND MARKETS ////////////////////
  address[] MARKETS;
  address marketPlaceOne;
  address marketPlaceTwo;

  address[] POINTTOKENS;
  MockERC20 PointTokenOne;
  MockERC20 PointTokenTwo;
  
  address[] TOKENS;
  MockERC20 USDC;
  MockERC20 USDT;
  MockERC20 UST;
  WETH9 weth;
  
  address[] ALL_TOKENS;


  uint256 internal constant INITIAL_USD_BALANCE = 1_000_000;
  uint256 internal constant INITIAL_ETH_BALANCE = 100_000;

  ///////////////////// ACTORS ////////////////////
  // address user = 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;
  // address user1 = 0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF;
  // address user2 = 0x6813Eb9362372EEF6200f3b1dbC3f819671cBA69;
  // address user3 = 0x1efF47bc3a10a45D4B230B5d10E37751FE6AA718;

  address OWNER;
  address[] USERS;
  address internal constant BOB = 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;
  address internal constant ALICE = 0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF;
  address internal constant JAKE = 0x6813Eb9362372EEF6200f3b1dbC3f819671cBA69;

  /*//////////////////////////////////////////////////////////////////////////
                                  TEST CONTRACTS
  //////////////////////////////////////////////////////////////////////////*/
  SystemConfig systemConfig;
  CapitalPool capitalPool;
  TokenManager tokenManager;
  PreMarktes preMarktes;
  DeliveryPlace deliveryPlace;

  /*//////////////////////////////////////////////////////////////////////////
                                SET-UP FUNCTION
  //////////////////////////////////////////////////////////////////////////*/

  function setup() internal virtual override {
    OWNER = address(this);

    // deploy mocks
    weth = new WETH9();

    TadleFactory tadleFactory = new TadleFactory(OWNER);

    USDC = new MockERC20("USDC", "USDC", 6);
    USDT = new MockERC20("USDT", "USDT", 18);
    UST = new MockERC20("UST", "UST", 32);
    PointTokenOne = new MockERC20("PTO", "PTO", 18);
    PointTokenTwo = new MockERC20("PTT", "PTT", 18);

    TOKENS = new address[](4);
    TOKENS[0] = address(USDC);
    TOKENS[1] = address(USDT);
    TOKENS[2] = address(UST);
    TOKENS[3] = address(weth);

    POINTTOKENS = new address[](2);
    POINTTOKENS[0] = address(PointTokenOne);
    POINTTOKENS[1] = address(PointTokenTwo);

    ALL_TOKENS = new address[](6);
    ALL_TOKENS[0] = address(USDC);
    ALL_TOKENS[1] = address(USDT);
    ALL_TOKENS[2] = address(UST);
    ALL_TOKENS[3] = address(weth);
    ALL_TOKENS[4] = address(PointTokenOne);
    ALL_TOKENS[5] = address(PointTokenTwo);

    SystemConfig systemConfigLogic = new SystemConfig();
    CapitalPool capitalPoolLogic = new CapitalPool();
    TokenManager tokenManagerLogic = new TokenManager();
    PreMarktes preMarktesLogic = new PreMarktes();
    DeliveryPlace deliveryPlaceLogic = new DeliveryPlace();

    bytes memory deploy_data = abi.encodeWithSelector(
        INITIALIZE_OWNERSHIP_SELECTOR,
        OWNER
    );
    // vm.startPrank(OWNER);

    address systemConfigProxy = tadleFactory.deployUpgradeableProxy(
        1,
        address(systemConfigLogic),
        bytes(deploy_data)
    );

    address preMarktesProxy = tadleFactory.deployUpgradeableProxy(
        2,
        address(preMarktesLogic),
        bytes(deploy_data)
    );
    address deliveryPlaceProxy = tadleFactory.deployUpgradeableProxy(
        3,
        address(deliveryPlaceLogic),
        bytes(deploy_data)
    );
    address capitalPoolProxy = tadleFactory.deployUpgradeableProxy(
        4,
        address(capitalPoolLogic),
        bytes(deploy_data)
    );
    address tokenManagerProxy = tadleFactory.deployUpgradeableProxy(
        5,
        address(tokenManagerLogic),
        bytes(deploy_data)
    );

    // vm.stopPrank();
    // attach logic
    systemConfig = SystemConfig(systemConfigProxy);
    capitalPool = CapitalPool(capitalPoolProxy);
    tokenManager = TokenManager(tokenManagerProxy);
    preMarktes = PreMarktes(preMarktesProxy);
    deliveryPlace = DeliveryPlace(deliveryPlaceProxy);

    // vm.startPrank(OWNER);
    // initialize
    systemConfig.initialize(basePlatformFeeRate, baseReferralRate);
    tokenManager.initialize(address(weth));
    address[] memory tokenAddressList = new address[](4);

    tokenAddressList[0] = address(USDC);
    tokenAddressList[1] = address(USDT);
    tokenAddressList[2] = address(UST);
    tokenAddressList[3] = payable(address(weth));

    tokenManager.updateTokenWhiteListed(tokenAddressList, true);

    // create market place
    systemConfig.createMarketPlace("Backpack", false);
    systemConfig.createMarketPlace("Frontpouch", false);
    // vm.stopPrank();

    marketPlaceOne = GenerateAddress.generateMarketPlaceAddress("Backpack");
    marketPlaceTwo = GenerateAddress.generateMarketPlaceAddress("Frontpouch");

    MARKETS = new address[](2);
    MARKETS[0] = marketPlaceOne;
    MARKETS[1] = marketPlaceTwo;

    setupActors();
  }

  function setupActors() internal {
    USERS = new address[](3);
    USERS[0] = BOB;
    USERS[1] = ALICE;
    USERS[2] = JAKE;

    _topUpUsers();

    // set approval for all tokens
    for (uint256 i = 0; i < USERS.length; i++) {
      hevm.prank(USERS[i]);
      USDC.approve(address(tokenManager), type(uint256).max);
      hevm.prank(USERS[i]);
      USDT.approve(address(tokenManager), type(uint256).max);
      hevm.prank(USERS[i]);
      UST.approve(address(tokenManager), type(uint256).max);
      hevm.prank(USERS[i]);
      weth.approve(address(tokenManager), type(uint256).max);
      
      hevm.prank(USERS[i]);
      PointTokenOne.approve(address(tokenManager), type(uint256).max);
      hevm.prank(USERS[i]);
      PointTokenTwo.approve(address(tokenManager), type(uint256).max);
    }

  }




  /*//////////////////////////////////////////////////////////////////////////
                             HELPER FUNCTIONS & MODIFIERS
  //////////////////////////////////////////////////////////////////////////*/

  function _topUpUsers() internal {
    address user;
    for (uint256 i = 0; i < USERS.length; i++) {
      user = USERS[i];

      MockERC20(TOKENS[0]).mint(user, INITIAL_USD_BALANCE * (10 ** MockERC20(TOKENS[0]).decimals())); 
      MockERC20(TOKENS[1]).mint(user, INITIAL_USD_BALANCE * (10 ** MockERC20(TOKENS[1]).decimals())); 
      MockERC20(TOKENS[2]).mint(user, INITIAL_USD_BALANCE * (10 ** MockERC20(TOKENS[2]).decimals()));
      weth.mint(user, INITIAL_ETH_BALANCE * (10 ** weth.decimals()));
      hevm.deal(user, INITIAL_ETH_BALANCE * (10 ** weth.decimals())); // deal native eth
    }
  }
}
