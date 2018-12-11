const moment = require("moment");

const Daico = artifacts.require("DaicoTestable");
const MintableToken = artifacts.require("MintableToken");

contract("Daico", (accounts) => {

	const evercityMemberAddress = accounts[0];
	const projectOwnerAddress = accounts[1];
	const inverstorAddress = accounts[2];
	const otherAddress = accounts[3];

	const minQuorumRate = 70;
	const minVoteRate = 70;
	const tokenHoldersCount = 5;

	let daico;
	let daiToken;
	let projectToken;

	beforeEach(async() => {
		daiToken = await MintableToken.new();
		projectToken = await MintableToken.new();
		await projectToken.mint(inverstorAddress, 1);
		
		timestampsFinishAt = [
			moment.unix(web3.eth.getBlock("latest").timestamp).add(1, 'week').unix(),
			moment.unix(web3.eth.getBlock("latest").timestamp).add(5, 'weeks').unix()
		];
		daico = await Daico.new(daiToken.address, projectToken.address, projectOwnerAddress, 2, [1, 2], timestampsFinishAt, minVoteRate, minQuorumRate, tokenHoldersCount);
	});

	describe("onlyInvestor()", () => {
		it("should revert if method is called not by investor", async() => {
			await daico.vote(0, true, {from: otherAddress}).should.be.rejectedWith("revert");
		});

		it("should call method that can be executed only by investor", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
		});
	});

	describe("validTapIndex()", () => {
		it("should revert if tap index does not exist", async() => {
			await daico.isTapWithdrawAcceptedByInvestors(2).should.be.rejectedWith("revert");
		});

		it("should call method with valid tap index", async() => {
			await daico.isTapWithdrawAcceptedByInvestors(1).should.be.fulfilled;
		});
	});

	describe("validVotingIndex()", () => {
		it("should revert if voting index does not exist", async() => {
			await daico.vote(2, true, {from: inverstorAddress}).should.be.rejectedWith("revert");
		});

		it("should call method with valid tap index", async() => {
			await daico.vote(0, true, {from: inverstorAddress}).should.be.fulfilled;
		});
	});

});
