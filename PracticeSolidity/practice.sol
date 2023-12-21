//SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

contract Coin{
    address public minter;
    mapping (address => uint256) public balances;

    event Sent(address from,address to,uint256 amount);

    constructor() {
        minter = msg.sender;
    }

    function mint(address _receiver,uint256 _amount) public  {
        require(minter==msg.sender,"No Permission");
        require(_amount < 1e60);
        balances[_receiver] +=_amount;
    }

    function send(address _receiver,uint256 _amount) public {
        require(_amount <= balances[msg.sender],"insufficient");
        balances[_receiver]+=_amount;
        balances[msg.sender] -=_amount;
        emit Sent(msg.sender,_receiver,_amount);
    }
}