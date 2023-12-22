//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

contract BlindAuction {
    struct Bid {
        bytes32 blindedBid;//숨겨진 이 값은 value값과 fake인지 아닌지 정보가 encodePacked 한것을 keccak256으로 해시처리한것 
        uint deposit;//보증금 
    }

    address payable public beneficiary;
    uint public biddingEnd;
    uint public revealEnd;
    bool public ended;

    mapping(address => Bid[]) public bids;

    address public highestBidder;
    uint public highestBid;

    // Allowed withdrawals of previous bids
    mapping(address => uint) pendingReturns;

    event AuctionEnded(address winner, uint highestBid);
    event ShowBlockTimeStamp(uint time);
    /// Modifiers are a convenient way to validate inputs to
    /// functions. `onlyBefore` is applied to `bid` below:
    /// The new function body is the modifier's body where
    /// `_` is replaced by the old function body.
    modifier onlyBefore(uint _time) { require(block.timestamp < _time); _; }
    modifier onlyAfter(uint _time) { require(block.timestamp > _time); _; }

    constructor(
        uint _biddingTime,
        uint _revealTime,
        address payable _beneficiary
    )  {
        beneficiary = _beneficiary;
        biddingEnd = block.timestamp + _biddingTime;
        revealEnd = biddingEnd + _revealTime;
        emit ShowBlockTimeStamp(block.timestamp);
        emit ShowBlockTimeStamp(biddingEnd);
        emit ShowBlockTimeStamp(revealEnd);
    }
    //여기서 keccak256이 해시 생성해주는 함수인데 그래서 여기서 묶어서 blindedBid를 만들어 줘야한다 
    //또 중요한게 encodePacked로 3가지 값을 묶은다음 해시생생해서 정보를 숨기기에 blindedBid인것 
    /// Place a blinded bid with `_blindedBid` =
    /// keccak256(abi.encodePacked(value, fake, secret)).
    /// The sent VIC is only refunded if the bid is correctly
    /// revealed in the revealing phase. The bid is valid if the
    /// VIC sent together with the bid is at least "value" and
    /// "fake" is not true. Setting "fake" to true and sending
    /// not the exact amount are ways to hide the real bid but
    /// still make the required deposit. The same address can
    /// place multiple bids.
    function bid(uint _value,bool _fake,bytes32 _secret)
        public
        payable
        onlyBefore(biddingEnd)
    { // 끝나기전에 bid 하는 것 여기서 packed해서 넘겨준다 
        bytes32 _blindedBid = keccak256(abi.encodePacked(_value,_fake,_secret));    

        bids[msg.sender].push(Bid({
            blindedBid: _blindedBid,
            deposit: msg.value
        }));
    }

    /// Reveal your blinded bids. You will get a refund for all
    /// correctly blinded invalid bids and for all bids except for
    /// the totally highest.
    function reveal(
        uint[] memory _values,
        bool[] memory _fake,
        bytes32[] memory _secret
    )
        public
        onlyAfter(biddingEnd)
        onlyBefore(revealEnd)
    {
        //당연히 한 주소의 입찰한 것의 길이는 value등 의 길이와 같아야된다.
        uint length = bids[msg.sender].length;
        require(_values.length == length);
        require(_fake.length == length);
        require(_secret.length == length);

        uint refund;
        for (uint i = 0; i < length; i++) {
            Bid storage bidToCheck = bids[msg.sender][i];//입찰한것을 0번 부터 끝까지 확인한다 .
            (uint value, bool fake, bytes32 secret) =
                    (_values[i], _fake[i], _secret[i]);
            if (bidToCheck.blindedBid != keccak256(abi.encodePacked(value, fake, secret))) {
                // Bid was not actually revealed.
                // Do not refund deposit.
                continue;
            }
            refund += bidToCheck.deposit;
            //fake가 false라는 것은 진짜 입찰,그리고 value값보다 보증금이 입찰값보다 크기에 placebid로 최고입찰 갱신후 
            //총환불금액에서 빼준다 이러면 진짜 입찰 말곤 다 refund 되는것 
            if (!fake && bidToCheck.deposit >= value) {
                if (placeBid(msg.sender, value))
                    refund -= value;
            }
            // Make it impossible for the sender to re-claim
            // the same deposit.
            bidToCheck.blindedBid = bytes32(0);
        }
        payable(msg.sender).transfer(refund);
    }

    /// Withdraw a bid that was overbid.
    function withdraw() public {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            // It is important to set this to zero because the recipient
            // can call this function again as part of the receiving call
            // before `transfer` returns (see the remark above about
            // conditions -> effects -> interaction).
            pendingReturns[msg.sender] = 0;

            payable(msg.sender).transfer(amount);
        }
    }

    /// End the auction and send the highest bid
    /// to the beneficiary.
    function auctionEnd()
        public
        onlyAfter(revealEnd)
    {
        require(!ended);
        emit AuctionEnded(highestBidder, highestBid);
        ended = true;
        beneficiary.transfer(highestBid);
    }

    // This is an "internal" function which means that it
    // can only be called from the contract itself (or from
    // derived contracts).
    function placeBid(address bidder, uint value) internal
            returns (bool success)
    {
        if (value <= highestBid) {
            return false;
        }
        if (highestBidder != address(0)) {
            // Refund the previously highest bidder.
            pendingReturns[highestBidder] += highestBid;
        }
        highestBid = value;
        highestBidder = bidder;
        return true;
    }
}