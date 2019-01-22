const moment = require("moment");

const Daico = artifacts.require("DaicoTestable");
const MintableToken = artifacts.require("MintableToken");

const { increaseTime } = require("./utils/helpers");


contract("Daico functional tests", (accounts) => {
	const evercityMember1 = accounts[0];
	const evercityMember2 = accounts[9];
	const projectOwner = accounts[1];
	const inverstor1 = accounts[2];
	const inverstor2 = accounts[3];
	const inverstor3 = accounts[4];
	const inverstor4 = accounts[5];
	const inverstor5 = accounts[6];
	const returnFunds = accounts[7];
	const other = accounts[8];

	const VOTING_TYPE_RELEASE_TAP = 0;
	const VOTING_TYPE_RELEASE_TAP_DECREASED_QUORUM = 1;
	const VOTING_TYPE_CHANGE_ROADMAP = 2;
	const VOTING_TYPE_CHANGE_ROADMAP_DECREASED_QUORUM = 3;
	const VOTING_TYPE_TERMINATE_PROJECT = 4;
	const VOTING_TYPE_TERMINATE_PROJECT_DECREASED_QUORUM = 5;

	const VOTING_RESULT_ACCEPT = 0;
	const VOTING_RESULT_DECLINE = 1;
	const VOTING_RESULT_QUORUM_NOT_REACHED = 2;
	const VOTING_RESULT_NO_DECISION = 3;

	const minQuorumRate = 70;
	const minVoteRate = 70;
	const days = 24 * 60 * 60;

	let daico;
	let daiToken;
	let projectToken;
	let timestampsFinishAt;

	describe("Different scenarios", () => {
		beforeEach(async() => {	
			// 1.1. evercityMember деплоит daiToken
			daiToken = await MintableToken.new({from: evercityMember1});
			
			// 1.2. У двух evercityMember появляются daiToken
			await daiToken.mint(evercityMember1, 100, {from: evercityMember1});
			await daiToken.mint(evercityMember2, 150, {from: evercityMember1});
			
			// 1.3. projectOwner деплоит projectToken
			projectToken = await MintableToken.new({from: projectOwner});
			
			// 1.4. projectOwner продает эти токены инвесторам (вне приложения, возможно за фиат)
			await projectToken.mint(inverstor1, 200, {from: projectOwner});
			await projectToken.mint(inverstor2, 501, {from: projectOwner});
			await projectToken.mint(inverstor3, 150, {from: projectOwner});
			await projectToken.mint(inverstor4, 149, {from: projectOwner});

			// 1.5. projectOwner: 
				// согласует значения minVoteRate, minQuorumRate (или ставит произвольные),
				// узнает daiToken, returnFunds
				// деплоит Daico контракт
				// evercityMember1 и evercityMember2 проверяют все значения (например, что returnFunds тот самый, иначе projectOwner может смошенничать)
			timestampsFinishAt = [
				moment.unix(web3.eth.getBlock("latest").timestamp).add(1, 'week').unix(),
				moment.unix(web3.eth.getBlock("latest").timestamp).add(1, 'week').unix(),
				moment.unix(web3.eth.getBlock("latest").timestamp).add(1, 'week').unix()
			];		
			daico = await Daico.new(daiToken.address, projectToken.address, projectOwner, returnFunds, 3, [50, 100, 100], timestampsFinishAt, minVoteRate, minQuorumRate, {from: projectOwner});
			
			// 1.6. evercityMember1 и evercityMember2 переводят токены на Daico адрес, который им дал projectOwner
			await daiToken.transfer(daico.address, 100, {from: evercityMember1});
			await daiToken.transfer(daico.address, 150, {from: evercityMember2});
		});

		it("1. Стандартный сценарий: все идет хорошо", async() => {
			// 1.7. Первая стадия голосования наступает автоматически, создавать голосование не требуется
			//	 minVoteRate == minQuorumRate == 70%, то есть голосов inverstor1 (200/1000) и inverstor2 (501/1000) достаточно, чтобы перейти на следующий stage
			await daico.vote(0, true, {from: inverstor1}).should.be.fulfilled;
			await daico.vote(0, true, {from: inverstor2}).should.be.fulfilled;
		
			// 1.8. Проходит неделя и projectOwner снимает часть средств.			
			assert.equal(await daiToken.balanceOf(projectOwner), 0);
			await daico.withdrawTapPayment(0, {from: projectOwner}).should.be.fulfilled;
			assert.equal(new web3.BigNumber(await daiToken.balanceOf(projectOwner)).toNumber(), 50);

			// 1.9. Проходит неделя, projectOwner создает новое голосование и инвесторы голосуют по новой.
			await increaseTime(7 * days);
			await daico.createVotingByOwner(1, VOTING_TYPE_RELEASE_TAP, {from: projectOwner});
			
			await daico.vote(1, true, {from: inverstor2}).should.be.fulfilled;
			await daico.vote(1, true, {from: inverstor3}).should.be.fulfilled;
			await daico.vote(1, true, {from: inverstor4}).should.be.fulfilled;
			await daico.withdrawTapPayment(1, {from: projectOwner}).should.be.fulfilled;

			// 1.10. И Снова
			await increaseTime(7 * days);
			await daico.createVotingByOwner(2, VOTING_TYPE_RELEASE_TAP, {from: projectOwner});
			await daico.vote(2, true, {from: inverstor2}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstor3}).should.be.fulfilled;
			await daico.vote(2, true, {from: inverstor4}).should.be.fulfilled;
			await daico.withdrawTapPayment(2, {from: projectOwner}).should.be.fulfilled;	

			// Проверяем баланс – projectOwner должен был получить все daiToken, которые проинвестировали
			assert.equal(await daiToken.balanceOf(projectOwner), 250);
		});
	});
});
