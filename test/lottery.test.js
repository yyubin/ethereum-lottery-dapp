const Lottery = artifacts.require("Lottery");
const { assert } = require("chai");
const assertRevert = require("./asserRevert");
const expectEvent = require("./expectEvent");

contract('Lottery', function([deployer, user1, user2]){
    let lottery;
    let betAmount = 5 * 10 ** 15;
    let bet_block_interval = 3;
    let betAmountBN = new web3.utils.BN('5000000000000000')

    beforeEach(async () => {
        lottery = await Lottery.new();
    })

    it('getPot should return current pot', async () => {
        let pot = await lottery.getPot();
        assert.equal(pot, 0)
    })

    describe('Bet', function () {
        it('should fail when the bet money is not 0.005 ETH', async () => {
            // Fail transaction
            await assertRevert(lottery.bet('0xab', {from: user1, value: 4000000000000000}))

            // transaction object {chainId, value, to, from, gas(Limit), gasPrice}
        })
        it('should put the bet to the bet queue with 1 bet', async () => {
            // bet
            let receipt = await lottery.bet('0xab', {from: user1, value: 5000000000000000})
            // console.log(receipt);

            let pot = await lottery.getPot();
            assert.equal(pot, 0);

            // check contract balance == 0.005
            let contractBalance = await web3.eth.getBalance(lottery.address);
            assert.equal(contractBalance, betAmount);

            // check bet info
            let currentBlockNumber = await web3.eth.getBlockNumber();
            let bet = await lottery.getBetInfo(0);
            
            assert.equal(bet.answerBlockNumber, currentBlockNumber + bet_block_interval);
            assert.equal(bet.bettor, user1);
            assert.equal(bet.challenges, '0xab');

            // check log
            await expectEvent.inLogs(receipt.logs, 'BET');
        })
    })

    describe.only('Distribute', function () {
        describe('When the answer is checkable', function () {
            it('should give the user the pot when the answer matches', async () => {
                // 두 글자 맞춘 경우
                await lottery.setAnswerForTest('0xabec17438e4f0afb9cc8b77ce84bb7fd501497cfa9a1695095247daa5b4b7bcc', {from:deployer})
                
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 1 -> 4
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 2 -> 5
                await lottery.betAndDistribute('0xab', {from:user1, value:betAmount}) // 3 -> 6
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 4 -> 7
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 5 -> 8
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 6 -> 9
                
                let potBefore = await lottery.getPot(); //  == 0.01 ETH
                let user1BalanceBefore = await web3.eth.getBalance(user1);
                
                let receipt7 = await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 7 -> 10 // user1에게 pot이 간다

                let potAfter = await lottery.getPot(); // == 0
                let user1BalanceAfter = await web3.eth.getBalance(user1); // == before + 0.015 ETH
                
                // pot 의 변화량 확인
                assert.equal(potBefore.toString(), new web3.utils.BN('10000000000000000').toString());
                assert.equal(potAfter.toString(), new web3.utils.BN('0').toString());
                
                // user의 밸런스 확인
                user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                assert.equal(user1BalanceBefore.add(potBefore).add(betAmountBN).toString(), user1BalanceAfter);
            })
            it('should give the user the amount when a single character matches', async () => {
                // 한 글자 맞춘 경우
                await lottery.setAnswerForTest('0xabec17438e4f0afb9cc8b77ce84bb7fd501497cfa9a1695095247daa5b4b7bcc', {from:deployer})
                
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 1 -> 4
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 2 -> 5
                await lottery.betAndDistribute('0xaf', {from:user1, value:betAmount}) // 3 -> 6
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 4 -> 7
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 5 -> 8
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 6 -> 9
                
                let potBefore = await lottery.getPot(); //  == 0.01 ETH
                let user1BalanceBefore = await web3.eth.getBalance(user1);
                
                let receipt7 = await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 7 -> 10 // user1에게 pot이 간다

                let potAfter = await lottery.getPot(); // == 0.01 ETH
                let user1BalanceAfter = await web3.eth.getBalance(user1); // == before + 0.005 ETH
                
                // pot 의 변화량 확인
                assert.equal(potBefore.toString(), potAfter.toString());

                // user(winner)의 밸런스를 확인
                user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                assert.equal(user1BalanceBefore.add(betAmountBN).toString(), new web3.utils.BN(user1BalanceAfter).toString())
            })
            it('should get the eth of user when the answer does not match at all', async () => {
                // 못 맞춘 경우
                await lottery.setAnswerForTest('0xabec17438e4f0afb9cc8b77ce84bb7fd501497cfa9a1695095247daa5b4b7bcc', {from:deployer})
                
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 1 -> 4
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 2 -> 5
                await lottery.betAndDistribute('0xef', {from:user1, value:betAmount}) // 3 -> 6
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 4 -> 7
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 5 -> 8
                await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 6 -> 9
                
                let potBefore = await lottery.getPot(); //  == 0.01 ETH
                let user1BalanceBefore = await web3.eth.getBalance(user1);
                
                let receipt7 = await lottery.betAndDistribute('0xef', {from:user2, value:betAmount}) // 7 -> 10 // user1에게 pot이 간다

                let potAfter = await lottery.getPot(); // == 0.015 ETH
                let user1BalanceAfter = await web3.eth.getBalance(user1); // == before
                
                // pot 의 변화량 확인
                assert.equal(potBefore.add(betAmountBN).toString(), potAfter.toString());

                // user(winner)의 밸런스를 확인
                user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                assert.equal(user1BalanceBefore.toString(), new web3.utils.BN(user1BalanceAfter).toString())
            })                        
        })
        describe('When the answer is not revealed(Not Mined)', function () {

        })
        describe('When the answer is not revealed(Block limit is passed)', function () {

        })
    })

    describe('isMatch', function () {
        it('should be BettingResult.Win when two characters match', async () => {
            let blockHash = '0xabab6db7d91e3a883a69abdd200a3de5255ac7c4cd39f79ce9f665eb2fbe29ad'
            let mathcingReulst = await lottery.isMatch('0xab', blockHash)
            assert.equal(mathcingReulst, 1);
        })
        
        it('should be BettingResult.Win when two characters match', async () => {
            let blockHash = '0xabab6db7d91e3a883a69abdd200a3de5255ac7c4cd39f79ce9f665eb2fbe29ad'
            let mathcingReulst = await lottery.isMatch('0xa9', blockHash)
            assert.equal(mathcingReulst, 2);

            mathcingReulst = await lottery.isMatch('0x8b', blockHash)
            assert.equal(mathcingReulst, 2);
        })

        it('should be BettingResult.Win when two characters match', async () => {
            let blockHash = '0xabab6db7d91e3a883a69abdd200a3de5255ac7c4cd39f79ce9f665eb2fbe29ad'
            let mathcingReulst = await lottery.isMatch('0x29', blockHash)
            assert.equal(mathcingReulst, 0);
        })
    })
});