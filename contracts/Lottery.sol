// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.6.0;

contract Lottery {
    struct BetInfo {
        uint256 answerBlockNumber;
        address payable bettor;
        byte challenges;
    }

    bool private mode = false; // false: use answer for test, true: use real block hash
    bytes32 public answerForTest;

    uint256 private _tail;
    uint256 private _head;
    mapping (uint256 => BetInfo) private _bets;

    address payable public owner;

    uint256 constant internal BLOCK_LIMIT = 256;
    uint256 constant internal BET_BLOCK_INTERVAL = 3;
    uint256 constant internal BET_AMOUNT = 5 * 10 ** 15;
    
    uint256 private _pot;

    event BET(uint256 index, address bettor, uint256 amount, byte challenges, uint256 answerBlockNumber);
    event WIN(uint256 index, address bettor, uint256 amount, byte challenges, byte answer, uint256 answerBlcokNumber);
    event FAIL(uint256 index, address bettor, uint256 amount, byte challenges, byte answer, uint256 answerBlcokNumber);
    event DRAW(uint256 index, address bettor, uint256 amount, byte challenges, byte answer, uint256 answerBlcokNumber);
    event REFUND(uint256 index, address bettor, uint256 amount, byte challenges, uint256 answerBlcokNumber);
    
    enum BlockStatus {Checkable, NotRevealed, BlockLimitPassed}
    enum BettingResult {Fail, Win, Draw}

    constructor() public {
        owner = msg.sender;
    }

    function getPot() public view returns (uint256 pot) {
        return _pot;
    }

    /**
     * @dev 배팅과 정답 체크
     * 큐에 저장된 배팅 정보는 distribute에서 해결
     * @param challenges 유저가 배팅하는 글자
     * @return 함수 수행 확인 boolean
     */
    function betAndDistribute(byte challenges) public payable returns (bool result) {
        bet(challenges);

        distribute();

        return true;
    }

    // Bet
    /**
     * @dev 배팅, 유저는 0.005 ETH를 보내야 하고 배팅용 1 byte를 전송
     * 큐에 저장된 배팅 정보는 distribute에서 해결
     * @param challenges 유저가 배팅하는 글자
     * @return 함수 수행 확인 boolean
     */
    function bet(byte challenges) public payable returns (bool result) {
        // check the proper ether is sent
        require(msg.value == BET_AMOUNT, "Not enough ETH");
        
        // push bet to the queue
        require(pushBet(challenges), "Fail to add a new Bet Info");
        
        // event log
        emit BET(_tail - 1, msg.sender, msg.value, challenges, block.number + BET_BLOCK_INTERVAL);
        return true;
    }
    // save the bet to the queue

    /**
     * @dev 배팅 결과값을 확인하고 팟머니 분배
     * 정답 실패 : 팟머니 축적, 정답 맞춤 : 팟머니 획득, 한글자 맞춤 or 정답 확인 불가 : 배팅 금액 환불
     */
    // Distribute
    function distribute() public {
        // head 3 4 5 6 7 8 9 10 11 12 tail
        uint256 cur;
        uint256 transferAmount;

        BetInfo memory b;
        BlockStatus currentBlockStatus;
        BettingResult currentBettingResult;

        for(cur=_head;cur<_tail;cur++) {
            b = _bets[cur];
            currentBlockStatus = getBlockStatus(b.answerBlockNumber);
            // Checkable : block.number > AnswerBlockNumber && block.number  <  BLOCK_LIMIT + AnswerBlockNumber 1
            if(currentBlockStatus == BlockStatus.Checkable) {
                bytes32 answerBlockHash = getAnswerBlockHash(b.answerBlockNumber);
                currentBettingResult = isMatch(b.challenges, answerBlockHash);
                // if win, bettor gets pot
                if(currentBettingResult == BettingResult.Win) {
                    // transfer pot
                    transferAmount = transferAfterPayingFee(b.bettor, _pot + BET_AMOUNT);
                    
                    // pot = 0
                    _pot = 0;

                    // emit WIN
                    emit WIN(cur, b.bettor, transferAmount, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }
                // if fail, bettor's money goes pot
                if(currentBettingResult == BettingResult.Fail) {
                    // pot = pot + BET_AMOUNT
                    _pot += BET_AMOUNT;
                    // emit FAIL
                    emit FAIL(cur, b.bettor, 0, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }
                
                // if draw, refund bettor's money 
                if(currentBettingResult == BettingResult.Draw) {
                    // transfer only BET_AMOUNT
                    transferAmount = transferAfterPayingFee(b.bettor, BET_AMOUNT);

                    // emit DRAW
                    emit DRAW(cur, b.bettor, transferAmount, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }
            }

            // Not Revealed : block.number <= AnswerBlockNumber 2
            if(currentBlockStatus == BlockStatus.NotRevealed) {
                break;
            }

            // Block Limit Passed : block.number >= AnswerBlockNumber + BLOCK_LIMIT 3
            if(currentBlockStatus == BlockStatus.BlockLimitPassed) {
                // refund
                transferAmount = transferAfterPayingFee(b.bettor, BET_AMOUNT);
                // emit refund
                emit REFUND(cur, b.bettor, transferAmount, b.challenges, b.answerBlockNumber);
            }

            popBet(cur);
        }
        _head = cur;
    }

    function transferAfterPayingFee(address payable addr, uint256 amount) internal returns (uint256) {
        uint256 fee = 0;
        uint256 amountWithoutFee = amount - fee;

        // transfer to addr
        addr.transfer(amountWithoutFee);

        // transfer to owner
        owner.transfer(fee);

        // call, send, transfer

        return amountWithoutFee;
    }

    function setAnswerForTest(bytes32 answer) public returns (bool result) {
        require(msg.sender == owner, "Only owner can set the answer for test mode");
        answerForTest = answer;
        return true;
    }

    function getAnswerBlockHash(uint256 answerBlockNumber) internal view returns (bytes32 answer) {
        return mode ? blockhash(answerBlockNumber) : answerForTest;
    }

    /**
     * @dev 배팅글자와 정답 확인
     * @param challenges 배팅 글자
     * @param answer 블록해시
     * @return 정답결과
     */
    function isMatch(byte challenges, bytes32 answer) public pure returns (BettingResult) {
        // challenges 0xab
        // answer 0xab.......ff 32 bytes

        byte c1 = challenges;
        byte c2 = challenges;

        byte a1 = answer[0];
        byte a2 = answer[0];

        // Get First Number
        c1 = c1 >> 4; // 0xab -> 0x0a
        c1 = c1 << 4; // 0x0a -> 0xa0

        a1 = a1 >> 4;
        a1 = a1 << 4;

        // Get Second Number
        c2 = c2 << 4; // 0xab -> 0xb0
        c2 = c2 >> 4; // 0xb0 -> 0x0b

        a2 = a2 << 4;
        a2 = a2 >> 4;

        if (a1 == c1 && a2 == c2) {
            return BettingResult.Win;
        }

        if (a1 == c1 || a2 == c2) {
            return BettingResult.Draw;
        }

        return BettingResult.Fail;

    }

    function getBlockStatus(uint256 answerBlockNumber) internal view returns (BlockStatus) {
        if(block.number > answerBlockNumber && block.number < BLOCK_LIMIT + answerBlockNumber) {
            return BlockStatus.Checkable;
        }
        if(block.number <= answerBlockNumber) {
            return BlockStatus.NotRevealed;
        }
        if(block.number >= answerBlockNumber + BLOCK_LIMIT) {
            return BlockStatus.BlockLimitPassed;
        }

        return BlockStatus.BlockLimitPassed;
    }


    function getBetInfo(uint256 index) public view returns (uint256 answerBlockNumber, address bettor, byte challenges) {
        BetInfo memory b = _bets[index];
        answerBlockNumber = b.answerBlockNumber;
        bettor = b.bettor;
        challenges = b.challenges;
    }
    
    function pushBet(byte challenges) public returns (bool) {
        BetInfo memory b;
        b.bettor = msg.sender;
        b.answerBlockNumber = block.number + BET_BLOCK_INTERVAL;
        b.challenges = challenges;

        _bets[_tail] = b;
        _tail++;

        return true;
    }

    function popBet(uint256 index) public returns (bool) {
        delete _bets[index];
        return true;
    }
}