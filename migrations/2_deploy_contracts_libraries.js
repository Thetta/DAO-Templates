var migrateLibs = require('@thetta/core/scripts/migrateLibs');

module.exports = function (deployer, network, accounts) {
     let additionalContracts = [ "./BodDaoFactory"
                           , "./DevZenDaoAuto"
                           , "./DevZenDaoAutoTestable"
                           , "./DevZenDaoFactory"
                           , "./DevZenDaoFactoryTestable"
                           , "./DevZenDaoTestable"
                           , "./DevZenDaoWithUnpackers"
                           , "./DevZenDaoWithUnpackersTestable"
                           , "./HierarchyDaoFactory"
                           , "./DaicoFactory"
                           , "./Daico"
                           , "./DaicoAuto"
                           , "./DaicoWithUnpackers"
                           ]

     return migrateLibs(artifacts, additionalContracts, deployer, network, accounts);
};
