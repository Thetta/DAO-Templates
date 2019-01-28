const moment = require("moment");

const Daico = artifacts.require("Daico");
const MintableToken = artifacts.require("MintableToken");

const { increaseTime } = require("./utils/helpers");


contract("Daico functional tests", (accounts) => {
	const evercity = accounts[0];
	const projectOwner = accounts[1];
	const investor1 = accounts[2];
	const investor2 = accounts[3];
	const investor3 = accounts[4];
	const investor4 = accounts[5];
	const investor5 = accounts[6];
	const returnFunds = accounts[7];
	const other = accounts[8];

	let daico;
	let daiToken;
	let projectToken;
	let timestampsFinishAt;
	let days = 24*60*60;

	var TS = {
		Preparing : 0,
		Investing: 1, 
		Voting : 2,
		VotingDQ : 3,
		RoadmapPreparing : 4,
		RoadmapVoting : 5,
		RoadmapVotingDQ : 6,
		Success : 7,
		Terminated : 8
	}

	async function getTaps() {
		var data = await daico.getTaps();
		var out = [];
		for(var i = 0; i < data[0].length; i++) {
			out.push([new web3.BigNumber(data[0][i]).toNumber(), new web3.BigNumber(data[1][i]).toNumber()])
		}
		return out;
	}

	async function getProjectInfo() {
		var data = await daico.proj()
		return {
			owner: data[0],
			token: data[1],
			daiToken: data[2],
			createdAt: new web3.BigNumber(data[3]).toNumber(),
			startedAt: new web3.BigNumber(data[4]).toNumber(),
			investDuration: new web3.BigNumber(data[5]).toNumber(),
			votingDuration: new web3.BigNumber(data[6]).toNumber(),
			additionalDuration: new web3.BigNumber(data[7]).toNumber(),
			changeRoadmapDuration: new web3.BigNumber(data[8]).toNumber(),
			quorumPercent: new web3.BigNumber(data[9]).toNumber(),
			quorumDecresedPercent: new web3.BigNumber(data[10]).toNumber(),
			declinePercent: new web3.BigNumber(data[11]).toNumber(),
			consensusPercent: new web3.BigNumber(data[12]).toNumber()
		}
	}

	async function getTapsInfo() {
		var data = await daico.getTapsInfo()
		data[1] = data[1].map((t)=> new web3.BigNumber(t).toNumber())
		// data[3] = data[3].map((t)=> new web3.BigNumber(t).toNumber())
		return {
			currentTap: new web3.BigNumber(data[0]).toNumber(),
			tapsStages: data[1],
			currentVoting: new web3.BigNumber(data[2]).toNumber()
			// tapOuts: data[3]

		}
	}

	function isArrayEquals(arr1, arr2) {
		for(var i = 0; i < arr1.length; i++) {
			if(arr1[i] != arr2[i]) {
				console.log('Unequal:', arr1, arr2);
				return false;
			}
		}
		return true;
	}

	describe("Different scenarios", () => {
		beforeEach(async() => {
			// 1.1. evercityMember деплоит daiToken
			evercityToken = await MintableToken.new({from: evercity});

			// 1.2. У инвесторов появляются daiToken
			await evercityToken.mint(investor1, 100, {from: evercity});
			await evercityToken.mint(investor2, 100, {from: evercity});
			await evercityToken.mint(investor3, 150, {from: evercity});

			var owner = projectOwner;
			var daiToken = evercityToken.address;
			var returnAddress = evercity;
			var tapFunds = [100, 100, 100];
			var tapDurations = [30, 30, 30];
			daico = await Daico.new(owner, daiToken, returnAddress, tapFunds, tapDurations, {from:projectOwner});

			await evercityToken.approve(daico.address, 100, {from:investor1});
			await evercityToken.approve(daico.address, 100, {from:investor2});
			await evercityToken.approve(daico.address, 100, {from:investor3});

			await daico.invest(100, {from:investor1});
			await daico.invest(50, {from:investor2});
			await daico.invest(50, {from:investor2});
			await daico.invest(100, {from:investor3});
			await daico.invest(50, {from:investor3}).should.be.rejectedWith('revert');
		});

		it(`1. Сценарий: все голосования происходят вовремя и без задержек, все голоса за`, async() => {
			await daico.withdrawFundsFromTap(0, {from:projectOwner});
			await increaseTime(23*days);

			 // Голосование началось
			await daico.vote(true, {from: investor1});
			await daico.vote(true, {from: investor2});
			await daico.vote(true, {from: investor3});
			await increaseTime(7*days); // голосование кончилось

			await daico.withdrawFundsFromTap(1, {from:projectOwner});

			await increaseTime(23*days); // Голосование началось
			await daico.vote(true, {from: investor1});
			await daico.vote(true, {from: investor2});
			await daico.vote(true, {from: investor3});
			await increaseTime(7*days); // голосование кончилось

			await daico.withdrawFundsFromTap(2, {from:projectOwner});
		});

		it(`2. Сценарий: задержки при голосовании. в первом голосует 66/70%, во втором (пониженный кворум) – 33/50%. 
			  Проект закрывается, средства возвращаются инвесторам`, async() => {
			assert.isTrue(isArrayEquals((await getTapsInfo()).tapsStages, [TS.Success, TS.Preparing, TS.Preparing]));
			await increaseTime(23*days);
			assert.isTrue(isArrayEquals((await getTapsInfo()).tapsStages, [TS.Success, TS.Voting, TS.Preparing]));
			 
			await daico.vote(true, {from: investor1});
			await daico.vote(true, {from: investor2});
			await increaseTime(7*days);
			assert.isTrue(isArrayEquals((await getTapsInfo()).tapsStages, [TS.Success, TS.VotingDQ, TS.Preparing]));
			await daico.vote(true, {from: investor1});
			await increaseTime(7*days);
			assert.isTrue(isArrayEquals((await getTapsInfo()).tapsStages, [TS.Success, TS.Terminated, TS.Preparing]));
		});

		it(`3. Сценарий: задержки при голосовании. в первом голосует 66/70%, во втором (пониженный кворум) – 66/50%. 
			  Далее аналогичная ситуация`, async() => {
			assert.isTrue(isArrayEquals((await getTapsInfo()).tapsStages, [TS.Success, TS.Preparing, TS.Preparing]));
			await increaseTime(23*days);
			assert.isTrue(isArrayEquals((await getTapsInfo()).tapsStages, [TS.Success, TS.Voting, TS.Preparing]));
			 
			await daico.vote(true, {from: investor1});
			await daico.vote(true, {from: investor2});
			await increaseTime(7*days);
			assert.isTrue(isArrayEquals((await getTapsInfo()).tapsStages, [TS.Success, TS.VotingDQ, TS.Preparing]));
			await daico.vote(true, {from: investor1});
			await daico.vote(true, {from: investor2});
			await increaseTime(7*days);
			assert.isTrue(isArrayEquals((await getTapsInfo()).tapsStages, [TS.Success, TS.Success, TS.Preparing]));
			await increaseTime(23*days);
			await daico.vote(true, {from: investor1});
			await daico.vote(true, {from: investor2});
			await increaseTime(7*days);
			assert.isTrue(isArrayEquals((await getTapsInfo()).tapsStages, [TS.Success, TS.Success, TS.VotingDQ]));
			await daico.vote(true, {from: investor1});
			await daico.vote(true, {from: investor2});
			await increaseTime(7*days);
			assert.isTrue(isArrayEquals((await getTapsInfo()).tapsStages, [TS.Success, TS.Success, TS.Success]));
		});

		it(`4. Сценарий: отсутствия консенсуса. во втором голосовании один против, 
			заменяется roadmap (вместо последнего периода [100], [30] предлагается два периода [50, 150], [50, 50]), 
			его утверждают, привлекаются новые инвестиции`, async() => {
			// Есть некоторые особенности в реализации proposeNewRoadmap:
			// 1. Стадия дополнительных инвестиций длится ровно неделю, даже если все инвестиции уже собраны. 
			// 2. Новый roadmap должен содержать и предыдущие taps, притом пройденные taps и текущий в новом roadmap должны быть равны таковым в старом roadmap
			// 3. Новый roadmap должен требовать больше денег, чем предыдущий
			// 4. Должно быть больше или столько же stage
			await daico.withdrawFundsFromTap(0, {from:projectOwner});
			await increaseTime(23*days); // Голосование началось		 
			await daico.vote(true, {from: investor1});
			await daico.vote(true, {from: investor2});
			await daico.vote(false, {from: investor3});
			await increaseTime(7*days);
			
			await daico.proposeNewRoadmap([100, 100, 100, 150], [30, 30, 50, 50], {from: projectOwner});
			await increaseTime(21*days);
			assert.equal((await getTapsInfo()).tapsStages.toString(), [TS.Success, TS.RoadmapVoting, TS.Preparing, TS.Preparing].toString())
			await daico.vote(true, {from: investor1});
			await daico.vote(true, {from: investor2});
			await daico.vote(true, {from: investor3});
			await increaseTime(7*days);
			assert.equal((await getTapsInfo()).tapsStages.toString(), [TS.Success, TS.Investing, TS.Preparing, TS.Preparing].toString())

			await evercityToken.mint(investor1, 50, {from: evercity});
			await evercityToken.mint(investor2, 50, {from: evercity});
			await evercityToken.mint(investor3, 50, {from: evercity});

			await evercityToken.approve(daico.address, 50, {from:investor1});
			await evercityToken.approve(daico.address, 50, {from:investor2});
			await evercityToken.approve(daico.address, 50, {from:investor3});

			await daico.invest(50, {from:investor1});
			assert.equal((await getTapsInfo()).tapsStages.toString(), [TS.Success, TS.Investing, TS.Preparing, TS.Preparing].toString())

			await daico.invest(50, {from:investor2});
			assert.equal((await getTapsInfo()).tapsStages.toString(), [TS.Success, TS.Investing, TS.Preparing, TS.Preparing].toString())
			await daico.invest(50, {from:investor3});
			await increaseTime(7*days);
			assert.equal((await getTapsInfo()).tapsStages.toString(), [TS.Success, TS.Success, TS.Preparing, TS.Preparing].toString())
			
			await increaseTime(43*days); // Голосование началось
			assert.equal((await getTapsInfo()).tapsStages.toString(), [TS.Success, TS.Success, TS.Voting, TS.Preparing].toString())
			await daico.vote(true, {from: investor1});
			await daico.vote(true, {from: investor2});
			await daico.vote(true, {from: investor3});
			await increaseTime(7*days);
			assert.equal((await getTapsInfo()).tapsStages.toString(), [TS.Success, TS.Success, TS.Success, TS.Preparing].toString())
			await daico.withdrawFundsFromTap(2, {from:projectOwner});
			await increaseTime(43*days); // Голосование началось
			assert.equal((await getTapsInfo()).tapsStages.toString(), [TS.Success, TS.Success, TS.Success, TS.Voting].toString())
			await daico.vote(true, {from: investor1});
			await daico.vote(true, {from: investor2});
			await daico.vote(true, {from: investor3});
			await increaseTime(7*days);
			assert.equal((await getTapsInfo()).tapsStages.toString(), [TS.Success, TS.Success, TS.Success, TS.Success].toString())
			await daico.withdrawFundsFromTap(3, {from:projectOwner});
		});
	});
});










