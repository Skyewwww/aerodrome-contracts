// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./ExtendedBaseTest.sol";

contract VotingEscrowTest is ExtendedBaseTest {
    function testVotingEscrowFlow() public {
        // starting timestamp: 604801
        IVotingEscrow.LockedBalance memory locked;
        IVotingEscrow.UserPoint memory userPoint;
        IVotingEscrow.GlobalPoint memory globalPoint;

        // create lock 1 and check state
        // 1: +1 user point
        // +1 global point
        // blk: 1, ts: 604801
        // nft id               1
        // user points:         1
        // global point epoch:  1
        AERO.approve(address(escrow), type(uint256).max);
        escrow.createLock(TOKEN_1, MAXTIME); // 1

        locked = escrow.locked(1);
        assertEq(convert(locked.amount), TOKEN_1);
        assertEq(locked.end, 32054400);
        assertEq(locked.isPermanent, false);
        assertEq(escrow.slopeChanges(32054400), -31709791983);

        assertEq(escrow.userPointEpoch(1), 1);
        userPoint = escrow.userPointHistory(1, 1);
        assertEq(userPoint.bias, 997260242238764817); // (TOKEN_1 / MAXTIME) * (32054400 - 604801)
        assertEq(userPoint.slope, 31709791983); // TOKEN_1 / MAXTIME
        assertEq(userPoint.ts, 604801);
        assertEq(userPoint.blk, 1);
        assertEq(userPoint.permanent, 0);

        assertEq(escrow.epoch(), 1);
        globalPoint = escrow.pointHistory(1);
        assertEq(globalPoint.bias, 997260242238764817);
        assertEq(globalPoint.slope, 31709791983);
        assertEq(globalPoint.ts, 604801);
        assertEq(globalPoint.blk, 1);
        assertEq(globalPoint.permanentLockBalance, 0);

        // update global checkpoint, overwritten
        // blk: 1, ts: 604801
        // nft id               1
        // user points:         1
        // global point epoch:  1
        escrow.checkpoint();

        assertEq(escrow.epoch(), 1);
        globalPoint = escrow.pointHistory(1);
        assertEq(globalPoint.bias, 997260242238764817); // (TOKEN_1 / MAXTIME) * (32054400 - 604801)
        assertEq(globalPoint.slope, 31709791983); // TOKEN_1 / MAXTIME
        assertEq(globalPoint.ts, 604801);
        assertEq(globalPoint.blk, 1);
        assertEq(globalPoint.permanentLockBalance, 0);
        globalPoint = escrow.pointHistory(2);

        // user increases amount in same block
        // user point overwritten
        // global point overwritten
        // blk: 1, ts: 604801
        // nft id               1
        // user points:         1
        // global point epoch:  1
        escrow.increaseAmount(1, TOKEN_1);

        locked = escrow.locked(1);
        assertEq(convert(locked.amount), TOKEN_1 * 2);
        assertEq(locked.end, 32054400);
        assertEq(locked.isPermanent, false);
        assertEq(escrow.slopeChanges(32054400), -63419583967);

        assertEq(escrow.userPointEpoch(1), 1);
        userPoint = escrow.userPointHistory(1, 1);
        assertEq(userPoint.bias, 1994520484508979233); // (TOKEN_1 / MAXTIME) * 2 * (32054400 - 604801)
        assertEq(userPoint.slope, 63419583967); // (TOKEN_1 / MAXTIME) * 2
        assertEq(userPoint.ts, 604801);
        assertEq(userPoint.blk, 1);
        assertEq(userPoint.permanent, 0);

        assertEq(escrow.epoch(), 1);
        globalPoint = escrow.pointHistory(1);
        assertEq(globalPoint.bias, 1994520484508979233); // (TOKEN_1 / MAXTIME) * 2 * (32054400 - 604801)
        assertEq(globalPoint.slope, 63419583967); // (TOKEN_1 / MAXTIME) * 2
        assertEq(globalPoint.ts, 604801);
        assertEq(globalPoint.blk, 1);
        assertEq(globalPoint.permanentLockBalance, 0);

        skipAndRoll(1 hours);
        // increase amount in different block
        // 1: +1 user point
        // +1 global point
        // blk: 2, ts: 608401
        // nft id               1
        // user points:         2
        // global point epoch:  2
        escrow.increaseAmount(1, TOKEN_1);

        locked = escrow.locked(1);
        assertEq(convert(locked.amount), TOKEN_1 * 3);
        assertEq(locked.end, 32054400);
        assertEq(locked.isPermanent, false);
        assertEq(escrow.slopeChanges(32054400), -95129375951);

        assertEq(escrow.userPointEpoch(1), 2);
        // check prior point
        userPoint = escrow.userPointHistory(1, 1);
        assertEq(userPoint.bias, 1994520484508979233);
        assertEq(userPoint.slope, 63419583967);
        assertEq(userPoint.ts, 604801);
        assertEq(userPoint.blk, 1);
        assertEq(userPoint.permanent, 0);
        userPoint = escrow.userPointHistory(1, 2);
        assertEq(userPoint.bias, 2991438261025770049); // slope * (32054400 - 608401)
        assertEq(userPoint.slope, 95129375951);
        assertEq(userPoint.ts, 608401);
        assertEq(userPoint.blk, 2);
        assertEq(userPoint.permanent, 0);

        assertEq(escrow.epoch(), 2);
        globalPoint = escrow.pointHistory(1);
        assertEq(globalPoint.bias, 1994520484508979233);
        assertEq(globalPoint.slope, 63419583967);
        assertEq(globalPoint.ts, 604801);
        assertEq(globalPoint.blk, 1);
        assertEq(globalPoint.permanentLockBalance, 0);
        globalPoint = escrow.pointHistory(2);
        assertEq(globalPoint.bias, 2991438261025770049);
        assertEq(globalPoint.slope, 95129375951);
        assertEq(globalPoint.ts, 608401);
        assertEq(globalPoint.blk, 2);
        assertEq(globalPoint.permanentLockBalance, 0);

        skipAndRoll(1 weeks); // blk: 3
        skipAndRoll(1 weeks); // blk: 4
        vm.roll(10); // blk: 10 (at least 1 blk per epoch)

        // two weeks have passed
        // expect checkpoint to write three new global points, once at start of each epoch
        // and once more at the current timestamp
        // +3 global points
        // blk: 10, ts: 1814400
        // nft id               1
        // user points:         2
        // global point epoch:  5
        escrow.checkpoint();

        assertEq(escrow.epoch(), 5);
        // last point preserved
        globalPoint = escrow.pointHistory(2);
        assertEq(globalPoint.bias, 2991438261025770049); // slope * (32054400 - 608401)
        assertEq(globalPoint.slope, 95129375951);
        assertEq(globalPoint.ts, 608401);
        assertEq(globalPoint.blk, 2);
        assertEq(globalPoint.permanentLockBalance, 0);
        // when checkpoints are skipped during epochs, escrow attempts to
        // smooth the block numbers in the checkpoints across the epochs
        // based on the total time elapsed since the last checkpoint
        // and the total number of blocks that have occurred since the last checkpoint
        globalPoint = escrow.pointHistory(3);
        assertEq(globalPoint.bias, 2934246575333404800); // slope * (32054400 - 1209600)
        assertEq(globalPoint.slope, 95129375951);
        assertEq(globalPoint.ts, 1209600);
        assertEq(globalPoint.blk, 5);
        assertEq(globalPoint.permanentLockBalance, 0);
        globalPoint = escrow.pointHistory(4);
        assertEq(globalPoint.bias, 2876712328758240000); // slope * (32054400 - 1814400)
        assertEq(globalPoint.slope, 95129375951);
        assertEq(globalPoint.ts, 1814400);
        assertEq(globalPoint.blk, 9);
        assertEq(globalPoint.permanentLockBalance, 0);
        globalPoint = escrow.pointHistory(5);
        assertEq(globalPoint.bias, 2876369767875440449); // slope * (32054400 - 1818001)
        assertEq(globalPoint.slope, 95129375951);
        assertEq(globalPoint.ts, 1818001);
        assertEq(globalPoint.blk, 10);
        assertEq(globalPoint.permanentLockBalance, 0);

        // extend locktime in same block
        // 1: +1 user point
        // global point overwritten
        // blk: 10, ts: 1814400
        // nft id               1
        // user points:         3
        // global point epoch:  5
        escrow.increaseUnlockTime(1, MAXTIME);

        locked = escrow.locked(1);
        assertEq(convert(locked.amount), TOKEN_1 * 3);
        assertEq(locked.end, 33264000);
        assertEq(locked.isPermanent, false);
        assertEq(escrow.slopeChanges(32054400), 0);
        assertEq(escrow.slopeChanges(33264000), -95129375951);

        assertEq(escrow.userPointEpoch(1), 3);
        // check prior point
        userPoint = escrow.userPointHistory(1, 2);
        assertEq(userPoint.bias, 2991438261025770049); // slope * (33264000 - 1818001)
        assertEq(userPoint.slope, 95129375951);
        assertEq(userPoint.ts, 608401);
        assertEq(userPoint.blk, 2);
        assertEq(userPoint.permanent, 0);
        userPoint = escrow.userPointHistory(1, 3);
        assertEq(userPoint.bias, 2991438261025770049);
        assertEq(userPoint.slope, 95129375951);
        assertEq(userPoint.ts, 1818001);
        assertEq(userPoint.blk, 10);
        assertEq(userPoint.permanent, 0);

        assertEq(escrow.epoch(), 5);
        globalPoint = escrow.pointHistory(4);
        assertEq(globalPoint.bias, 2876712328758240000); // slope * (32054400 - 1814400)
        assertEq(globalPoint.slope, 95129375951);
        assertEq(globalPoint.ts, 1814400);
        assertEq(globalPoint.blk, 9);
        assertEq(globalPoint.permanentLockBalance, 0);
        globalPoint = escrow.pointHistory(5);
        assertEq(globalPoint.bias, 2991438261025770049); // slope * (33264000 - 1818001)
        assertEq(globalPoint.slope, 95129375951);
        assertEq(globalPoint.ts, 1818001);
        assertEq(globalPoint.blk, 10);
        assertEq(globalPoint.permanentLockBalance, 0);

        skipToNextEpoch(0);
        // checkpoint at start of next epoch
        // +1 global point only, as checkpoint occurs on flip
        // blk: 11, ts: 2419200
        // nft id               1
        // user points:         3
        // global point epoch:  6
        escrow.checkpoint();

        assertEq(escrow.epoch(), 6);
        globalPoint = escrow.pointHistory(5);
        assertEq(globalPoint.bias, 2991438261025770049); // slope * (33264000 - 1818001)
        assertEq(globalPoint.slope, 95129375951);
        assertEq(globalPoint.ts, 1818001);
        assertEq(globalPoint.blk, 10);
        assertEq(globalPoint.permanentLockBalance, 0);
        globalPoint = escrow.pointHistory(6);
        assertEq(globalPoint.bias, 2934246575333404800); // slope * (33264000 - 2419200)
        assertEq(globalPoint.slope, 95129375951);
        assertEq(globalPoint.ts, 2419200);
        assertEq(globalPoint.blk, 11);
        assertEq(globalPoint.permanentLockBalance, 0);
    }
}
