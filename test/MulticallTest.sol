// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./BaseTest.sol";
import { Multicall } from "../contracts/Multicall.sol";

contract MulticallTest is BaseTest {
    
    Multicall public multicall;
    address user = address(0x123);

    function _setUp() public override {
        multicall = new Multicall();

        uint256[] memory amounts = new uint256[](6);
        amounts[0] = 1e25;
        amounts[1] = 1e25;
        amounts[2] = 1e25;
        amounts[3] = 1e25;
        amounts[4] = 1e25;
        amounts[5] = 1e25;
        owners.push(address(multicall));
        mintToken(address(WETH), owners, amounts);
        dealETH(owners, amounts);

        USDC.transfer(address(multicall), USDC_100K);
        FRAX.transfer(address(multicall), TOKEN_100K);
    }

    function testApproveAndAddLiquidity() public {
        address pool = factory.getPool(address(FRAX), address(USDC), true);

        Multicall.Call[] memory calls = new Multicall.Call[](3);
        calls[0] = Multicall.Call(address(USDC), abi.encodeWithSignature("approve(address,uint256)", address(router), type(uint256).max));
        calls[1] = Multicall.Call(address(FRAX), abi.encodeWithSignature("approve(address,uint256)", address(router), type(uint256).max));
        calls[2] = Multicall.Call(address(router), abi.encodeWithSignature("addLiquidity(address,address,bool,uint256,uint256,uint256,uint256,address,uint256)", address(FRAX), address(USDC), true, TOKEN_100K, USDC_100K, TOKEN_100K, USDC_100K, user, block.timestamp));
        (uint256 blockNumber, bytes[] memory returnData) = multicall.aggregate(calls);

        assertEq(blockNumber, block.number);
        assertTrue(returnData.length == 3);
    }

    function testApproveAndAddLiquidityAndStake() public {
        testApproveAndAddLiquidity();
        address pool = factory.getPool(address(FRAX), address(USDC), true);
        address admin = address(0x123);
        uint256 lpBalance = IERC20(pool).balanceOf(admin);

        vm.prank(admin);
        IERC20(pool).approve(address(multicall), type(uint256).max);

        Multicall.Call[] memory calls = new Multicall.Call[](3);
        calls[0] = Multicall.Call(pool, abi.encodeWithSignature("transferFrom(address,address,uint256)", admin, address(multicall), lpBalance));
        calls[1] = Multicall.Call(pool, abi.encodeWithSignature("approve(address,uint256)", address(gauge), lpBalance));
        calls[2] = Multicall.Call(address(gauge), abi.encodeWithSignature("deposit(uint256,address)", lpBalance, admin));
        (uint256 blockNumber, bytes[] memory returnData) = multicall.aggregate(calls);

        assertEq(blockNumber, block.number);
        assertTrue(returnData.length == 3);
    }
}
