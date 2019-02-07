pragma solidity ^0.4.24;

import "zeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "./IDaico.sol";


contract STOContract is MintableToken {
	address public ervercityTokenAddress;
	address public daicoAddress;

	constructor(address _ervercityTokenAddress) public {		
		ervercityTokenAddress = _ervercityTokenAddress;
	}

	function setDaicoAddress(address _daicoAddress) public onlyOwner {
		daicoAddress = _daicoAddress;
	}

	function invest(uint _amount) public {
		ERC20(ervercityTokenAddress).transferFrom(msg.sender, address(this), _amount);
		ERC20(ervercityTokenAddress).approve(daicoAddress, _amount);

		totalSupply_ = totalSupply_.add(_amount);
		balances[msg.sender] = balances[msg.sender].add(_amount);
		emit Mint(msg.sender, _amount);
		emit Transfer(address(0), msg.sender, _amount);

		IDaico(daicoAddress).addInvestor(_amount, msg.sender);
	}
}
