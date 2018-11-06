const CheckExceptions = require("./utils/checkexceptions");
const should = require("./utils/helpers");

const DaicoFactory = artifacts.require("DaicoFactory");
const Daico = artifacts.require("Daico");
const DaicoWithUnpackers = artifacts.require("DaicoWithUnpackers");
const DaicoProject = artifacts.require("DaicoProject");


contract("Daico", (accounts) => {
	const creator = accounts[0];
	const investor1 = accounts[1];
	const investor2 = accounts[2];
	const investor3 = accounts[3];
	const projectOwner1 = accounts[4];
	const projectOwner2 = accounts[5];

	let daicoFactory;
	let daoBase;
	let store;
	let daicoAuto;
	let daico;

	beforeEach(async () => {
		daicoFactory = await DaicoFactory.new([investor1, investor2, investor3]);
		// daoBase = DaoBaseWithUnpackers.at(await daicoFactory.daoBase());
		// store = DaoStorage.at(await daicoFactory.store());
		// daicoAuto = DaicoAuto.at(await daicoFactory.daicoAuto());
		// daico = Daico.at(await daicoFactory.daico());
	});

	it("BoD member should be able to add new proposal", async () => {
		// await daico.addNewProject(5, 1000, { from: projectOwner1 }).should.be.fulfilled;
		
	});
});