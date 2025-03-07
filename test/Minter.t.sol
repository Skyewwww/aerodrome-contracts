// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./BaseTest.sol";

contract MinterTest is BaseTest {
    using stdStorage for StdStorage;
    uint256 tokenId;

    event AcceptTeam(address indexed _newTeam);
    event Nudge(uint256 indexed _period, uint256 _oldRate, uint256 _newRate);

    function _setUp() public override {
        AERO.approve(address(escrow), TOKEN_1);
        tokenId = escrow.createLock(TOKEN_1, MAXTIME);
        skip(1);

        address[] memory pools = new address[](2);
        pools[0] = address(pool);
        pools[1] = address(pool2);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1;
        weights[1] = 1;

        skip(1 hours);
        voter.vote(tokenId, pools, weights);
    }

    function testMinterDeploy() public {
        assertEq(minter.MAXIMUM_TAIL_RATE(), 380); // 3.8%
        assertEq(minter.MINIMUM_TAIL_RATE(), 4); // .04%
        assertEq(minter.STEADY_WEEKLY_DECAY(), 9_900);
        assertEq(minter.FIRST_WEEKLY_GROWTH(), 10_300);
        assertEq(minter.SECOND_WEEKLY_GROWTH(), 10_200);
        assertEq(minter.TAIL_START(), 4_275_016 * 1e18);
        assertEq(minter.weekly(), 4_000_000 * 1e18);
        assertEq(minter.tailEmissionRate(), 200); // 2%
        assertEq(minter.activePeriod(), 604800);
        assertEq(minter.team(), address(owner));
        assertEq(minter.teamRate(), 300); // 3%
        assertEq(minter.MAXIMUM_TEAM_RATE(), 500); // 5%
        assertEq(minter.pendingTeam(), address(0));
        assertEq(minter.epochCount(), 0);
        assertFalse(minter.initialized());
    }

    function testWeeklyEmissionGrowsFirst9WeeksThenFlipsAndDecays() public {
        minter.updatePeriod();
        assertEq(minter.weekly(), 4 * TOKEN_1M); // 4M
        assertEq(minter.epochCount(), 0);

        //epoch 1
        skipToNextEpoch(1);
        minter.updatePeriod();
        assertApproxEqAbs(minter.weekly(), 4_120_000 * TOKEN_1, TOKEN_1);
        assertEq(minter.epochCount(), 1);

        //epoch 2
        skipToNextEpoch(1);
        minter.updatePeriod();
        assertApproxEqAbs(minter.weekly(), 4_243_600 * TOKEN_1, TOKEN_1);
        assertEq(minter.epochCount(), 2);

        // epoch 3
        skipToNextEpoch(1);
        minter.updatePeriod();
        
        //epoch 4
        skipToNextEpoch(1);
        minter.updatePeriod();
        assertApproxEqAbs(minter.weekly(), 4_502_035  * TOKEN_1, TOKEN_1);
        assertEq(minter.epochCount(), 4);

        //epoch 5
        skipToNextEpoch(1);
        minter.updatePeriod();
        assertApproxEqAbs(minter.weekly(), 4_592_075 * TOKEN_1, TOKEN_1);
        assertEq(minter.epochCount(), 5);

        //epoch 6 - 7
        for(uint256 i = 6; i < 8; i++) {
            skipToNextEpoch(1);
            minter.updatePeriod();
        }

        //epoch 8
        skipToNextEpoch(1);
        minter.updatePeriod();
        assertApproxEqAbs(minter.weekly(), 4_873_147 * TOKEN_1, TOKEN_1);
        assertEq(minter.epochCount(), 8);

        //epoch 9
        skipToNextEpoch(1);
        minter.updatePeriod();
        assertApproxEqAbs(minter.weekly(), 4_970_610 * TOKEN_1, TOKEN_1);
        assertEq(minter.epochCount(), 9);

        //emissions grow for 1 - 9 weeks
        //in week 10 - 24, weekly emission flips and decays

        //epoch 10 - 23
        for(uint256 i = 10; i < 24; i++) {
            skipToNextEpoch(1);
            minter.updatePeriod();
        }

        //epoch 24
        skipToNextEpoch(1);
        minter.updatePeriod();
        assertApproxEqAbs(minter.weekly(), 4_275_015 * TOKEN_1, TOKEN_1);
        assertEq(minter.epochCount(), 24);
    }

    function testTailEmissionWhenWeeklyEmissionDecaysBelowTailStart() public {
        skipToNextEpoch(1);
        assertEq(AERO.balanceOf(address(voter)), 0);

        // 4_318_197 * 1e18 ~= approximate weekly value after 23 epochs
        // (last epoch prior to tail emissions kicking in)
        uint256 weekly = 4_318_197 * 1e18;
        stdstore.target(address(minter)).sig("weekly()").checked_write(weekly);
        stdstore.target(address(minter)).sig("epochCount()").checked_write(23);

        skipToNextEpoch(1);
        minter.updatePeriod();
        // community emissions kick in
        assertApproxEqAbs(minter.weekly(), 4_275_015 * TOKEN_1, TOKEN_1);
        assertApproxEqRel(AERO.balanceOf(address(voter)), 4_318_197 * TOKEN_1, 1e12);
        voter.distribute(0, voter.length());

        skipToNextEpoch(1);
        // if no nudges, emissions should be the sames
        minter.updatePeriod();
        assertApproxEqAbs(AERO.balanceOf(address(voter)), 1_133_525 * 1e18, TOKEN_1);
        assertLt(minter.weekly(), minter.TAIL_START());
    }

    function testCannotNudgeIfNotInTailEmissionsYet() public {
        vm.prank(address(epochGovernor));
        vm.expectRevert(IMinter.TailEmissionsInactive.selector);
        minter.nudge();
    }

    function testCannotNudgeIfNotEpochGovernor() public {
        /// put in tail emission schedule
        stdstore.target(address(minter)).sig("weekly()").checked_write(4_275_015 * 1e18);
        stdstore.target(address(minter)).sig("epochCount()").checked_write(24);

        vm.prank(address(owner2));
        vm.expectRevert(IMinter.NotEpochGovernor.selector);
        minter.nudge();
    }

    function testCannotNudgeIfAlreadyNudged() public {
        /// put in tail emission schedule
        stdstore.target(address(minter)).sig("weekly()").checked_write(4_275_015 * 1e18);
        stdstore.target(address(minter)).sig("epochCount()").checked_write(24);
        assertFalse(minter.proposals(604800));

        vm.prank(address(epochGovernor));
        minter.nudge();
        assertTrue(minter.proposals(604800));
        skip(1);

        vm.expectRevert(IMinter.AlreadyNudged.selector);
        vm.prank(address(epochGovernor));
        minter.nudge();
    }

    function testNudgeWhenAtUpperBoundary() public {
        stdstore.target(address(minter)).sig("weekly()").checked_write(4_275_015 * 1e18);
        stdstore.target(address(minter)).sig("epochCount()").checked_write(24);
        stdstore.target(address(minter)).sig("tailEmissionRate()").checked_write(380);
        /// note: see IGovernor.ProposalState for enum numbering
        stdstore.target(address(epochGovernor)).sig("result()").checked_write(4); // nudge up
        assertEq(minter.tailEmissionRate(), 380);

        vm.prank(address(epochGovernor));
        minter.nudge();

        assertEq(minter.tailEmissionRate(), 380); // nudge above at maximum does nothing

        skipToNextEpoch(1);
        minter.updatePeriod();

        stdstore.target(address(epochGovernor)).sig("result()").checked_write(3); // nudge down

        vm.expectEmit(true, false, false, true, address(minter));
        emit Nudge(1209600, 380, 376);
        vm.prank(address(epochGovernor));
        minter.nudge();

        assertEq(minter.tailEmissionRate(), 376);
        assertTrue(minter.proposals(1209600));

        skipToNextEpoch(1);
        minter.updatePeriod();

        stdstore.target(address(epochGovernor)).sig("result()").checked_write(6); // no nudge

        vm.expectEmit(true, false, false, true, address(minter));
        emit Nudge(1814400, 376, 376);
        vm.prank(address(epochGovernor));
        minter.nudge();

        assertEq(minter.tailEmissionRate(), 376);
        assertTrue(minter.proposals(1814400));
    }

    function testNudgeWhenAtLowerBoundary() public {
        stdstore.target(address(minter)).sig("weekly()").checked_write(4_275_015 * 1e18);
        stdstore.target(address(minter)).sig("epochCount()").checked_write(24);
        stdstore.target(address(minter)).sig("tailEmissionRate()").checked_write(4);
        /// note: see IGovernor.ProposalState for enum numbering
        stdstore.target(address(epochGovernor)).sig("result()").checked_write(3); // nudge down
        assertEq(minter.tailEmissionRate(), 4);

        vm.prank(address(epochGovernor));
        minter.nudge();

        assertEq(minter.tailEmissionRate(), 4); // nudge below at minimum does nothing

        skipToNextEpoch(1);
        minter.updatePeriod();

        stdstore.target(address(epochGovernor)).sig("result()").checked_write(4); // nudge up

        vm.expectEmit(true, false, false, true, address(minter));
        emit Nudge(1209600, 4, 8);
        vm.prank(address(epochGovernor));
        minter.nudge();

        assertEq(minter.tailEmissionRate(), 8);
        assertTrue(minter.proposals(1209600));

        skipToNextEpoch(1);
        minter.updatePeriod();

        stdstore.target(address(epochGovernor)).sig("result()").checked_write(6); // no nudge

        vm.expectEmit(true, false, false, true, address(minter));
        emit Nudge(1814400, 8, 8);
        vm.prank(address(epochGovernor));
        minter.nudge();

        assertEq(minter.tailEmissionRate(), 8);
        assertTrue(minter.proposals(1814400));
    }

    function testNudge() public {
        /// put in tail emission schedule
        stdstore.target(address(minter)).sig("weekly()").checked_write(4_275_015 * 1e18);
        stdstore.target(address(minter)).sig("epochCount()").checked_write(24);
        /// note: see IGovernor.ProposalState for enum numbering
        stdstore.target(address(epochGovernor)).sig("result()").checked_write(4); // nudge up
        assertEq(minter.tailEmissionRate(), 200);

        vm.expectEmit(true, false, false, true, address(minter));
        emit Nudge(604800, 200, 204);
        vm.prank(address(epochGovernor));
        minter.nudge();
        assertEq(minter.tailEmissionRate(), 204);
        assertTrue(minter.proposals(604800));

        skipToNextEpoch(1);
        minter.updatePeriod();

        stdstore.target(address(epochGovernor)).sig("result()").checked_write(3); // nudge down

        vm.expectEmit(true, false, false, true, address(minter));
        emit Nudge(1209600, 204, 200);
        vm.prank(address(epochGovernor));
        minter.nudge();

        assertEq(minter.tailEmissionRate(), 200);
        assertTrue(minter.proposals(1209600));

        skipToNextEpoch(1);
        minter.updatePeriod();

        stdstore.target(address(epochGovernor)).sig("result()").checked_write(6); // no nudge

        vm.expectEmit(true, false, false, true, address(minter));
        emit Nudge(1814400, 200, 200);
        vm.prank(address(epochGovernor));
        minter.nudge();

        assertEq(minter.tailEmissionRate(), 200);
        assertTrue(minter.proposals(1814400));
    }

    function testMinterWeeklyDistribute() public {
        minter.updatePeriod();
        assertEq(minter.weekly(), 4 * TOKEN_1M); // 10M

        uint256 pre = AERO.balanceOf(address(voter));
        skipToNextEpoch(1);
        minter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 1999996614880713098414583);
        // emissions decay by 1% after one epoch
        uint256 post = AERO.balanceOf(address(voter));
        assertEq(post - pre, (4 * TOKEN_1M));
        assertEq(minter.weekly(), ((4 * TOKEN_1M) * 103) / 100);

        pre = post;
        skipToNextEpoch(1);
        vm.roll(block.number + 1);
        minter.updatePeriod();
        post = AERO.balanceOf(address(voter));

        // check rebase accumulated
        assertEq(distributor.claimable(1), 4059996445358582765070695);
        distributor.claim(1);
        assertEq(distributor.claimable(1), 0);

        assertEq(post - pre, (4 * TOKEN_1M * 103) / 100);
        assertEq(minter.weekly(), (4 * TOKEN_1M * 103 * 103) / 100 / 100);

        skip(1 weeks);
        vm.roll(block.number + 1);
        minter.updatePeriod();

        distributor.claim(1);

        skip(1 weeks);
        vm.roll(block.number + 1);
        minter.updatePeriod();

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        distributor.claimMany(tokenIds);

        skip(1 weeks);
        vm.roll(block.number + 1);
        minter.updatePeriod();
        distributor.claim(1);

        skip(1 weeks);
        vm.roll(block.number + 1);
        minter.updatePeriod();
        distributor.claimMany(tokenIds);

        skip(1 weeks);
        vm.roll(block.number + 1);
        minter.updatePeriod();
        distributor.claim(1);
    }

    function testSetTeam() public {
        address team = minter.team();
        address newTeam = address(owner2);

        assertEq(minter.pendingTeam(), address(0));
        vm.prank(team);
        minter.setTeam(newTeam);
        assertEq(minter.team(), team);
        assertEq(minter.pendingTeam(), newTeam);
    }

    function testAcceptTeam() public {
        address newTeam = address(owner2);
        stdstore.target(address(minter)).sig("pendingTeam()").checked_write(newTeam);

        vm.prank(newTeam);
        vm.expectEmit(true, false, false, false, address(minter));
        emit AcceptTeam(newTeam);
        minter.acceptTeam();
        assertEq(minter.pendingTeam(), address(0));
        assertEq(minter.team(), newTeam);
    }

    function testSetRate() public {
        uint256 oldRate = 300;
        uint256 newRate = 400;
        assertEq(minter.teamRate(), oldRate);

        vm.prank(minter.team());
        minter.setTeamRate(newRate);
        assertEq(minter.teamRate(), newRate);
    }

    function testCannotSetTeamIfNotTeam() public {
        vm.prank(address(owner2));
        vm.expectRevert(IMinter.NotTeam.selector);
        minter.setTeam(address(owner2));
    }

    function testCannotSetTeamIfZeroAddress() public {
        vm.prank(address(owner));
        vm.expectRevert(IMinter.ZeroAddress.selector);
        minter.setTeam(address(0));
    }

    function testCannotAcceptTeamIfNotPending() public {
        vm.prank(address(owner));
        minter.setTeam(address(owner2));

        vm.prank(address(owner3));
        vm.expectRevert(IMinter.NotPendingTeam.selector);
        minter.acceptTeam();
    }

    function testCannotSetRateIfNotTeam() public {
        vm.prank(address(owner2));
        vm.expectRevert(IMinter.NotTeam.selector);
        minter.setTeamRate(400);
    }

    function testCannotSetRateTooHigh() public {
        uint256 maxRate = minter.MAXIMUM_TEAM_RATE();
        vm.prank(address(owner));
        vm.expectRevert(IMinter.RateTooHigh.selector);
        minter.setTeamRate(maxRate + 1);
    }
}
