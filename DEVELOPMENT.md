# Thetta DAO Templates (for Developers)

Please [submit issues here](https://github.com/Thetta/DAO-templates/projects/1).

[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

[ ![Codeship Status for Thetta/DAO-Templates](https://app.codeship.com/projects/2dda7d70-5ff8-0136-443b-02dfb7ae7eef/status?branch=master)](https://app.codeship.com/projects/296178)

## Testing  

```
npm run test
```

## Testing specific file

```
npm run test -- test/1-HierarchyDao.js
````

## CodeShip Continuous Integration script
``` bash
# reqs
npm install -g npm@6.1.0
nvm install 10.5.0
npm install -g ganache-cli

# solc is 0.4.23
# zeppelin-solidity is 1.9.0
npm install -g truffle@4.1.12

# test
npm run test

# coverage via coveralls.io
npm run coveralls
```