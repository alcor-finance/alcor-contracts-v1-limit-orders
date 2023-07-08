import { Decimal } from 'decimal.js'
import { BigNumber, Wallet } from 'ethers'
import { ethers } from 'hardhat'
import { expect } from '../shared/expect'

import { TokenERC20 } from '../../typechain/TokenERC20'
import { AlcorFactory } from '../../typechain/AlcorFactory'
import { MockAlcorPoolCallOption } from '../../typechain/MockAlcorPoolCallOption'

import { delay, tickToPrice } from '../shared/utils'
import { formatTokenAmount } from '../shared/format'

import { mumbaiFactoryAddr, mumbaiUSDC2, mumbaiWETH2 } from '../constants'

import {
    Tokens, deployTokensFixture,
    loadTokensFixture, FactoryFixture,
    createAlcorPoolCallOption,
    loadAlcorPoolCallOptionContract,
    loadAlcorFactory
} from '../shared/fixtures'


Decimal.config({ toExpNeg: -500, toExpPos: 500 })

const AlcorPoolsParams = [{
    isCallOption: true,
    optionExpiration: "1695978000",
    optionStrikePrice: ethers.utils.parseEther("2200")
}]

// deposits in token1
const DEPOSITS = [
    {
        owner: "0x29FA2F326b01203D8C31852d47f0d053Fc7Ce7E7", // dev1
        amount: ethers.utils.parseEther("2500000"),
        token: "token0",
        // tokenAddress: TOKENS[1]
    }, {
        owner: "0x29FA2F326b01203D8C31852d47f0d053Fc7Ce7E7", // dev2
        amount: ethers.utils.parseEther("15000000"),
        token: "token1",
        // tokenAddress: TOKENS[1]
    }
]



describe('AlcorPoolCallOptions buyOption tests', () => {
    let accountsLength: number = 3
    let account1: Wallet, account2: Wallet, account3: Wallet
    // let token0Addr: string, token1Addr: string
    let token0Addr = mumbaiUSDC2
    let token1Addr = mumbaiWETH2

    let factory: AlcorFactory
    let factoryAddress = mumbaiFactoryAddr
    let mock_alcor_pool_call_option_address: string
    const { isCallOption, optionExpiration, optionStrikePrice } = AlcorPoolsParams[0];

    // let loadFixture: ReturnType<typeof createFixtureLoader>
    before("load wallets", async () => {
        [account1, account2, account3] = await (ethers as any).getSigners()
        // accounts = await (ethers as any).getSigners()
        console.log(account1.address, account2.address, account3.address)
    })


    // console.log(accounts)

    // for (let i = 0; i < accountsLength; i++) {
    //     before("mint tokens to acc1, acc2 and acc3", async () => {
    //         let accounts = [account1, account2, account3]

    //         let [token0, token1] = await loadTokensFixture(token0Addr, token1Addr, accounts[i])

    //         let tx0 = await token0.mintToAddress(accounts[i].address, BigNumber.from(2).pow(100).toString())
    //         await tx0.wait();
    //         let tx1 = await token1.mintToAddress(accounts[i].address, BigNumber.from(2).pow(100).toString())
    //         await tx1.wait();
    //         console.log('i=', i, '; tokens minted')

    //     })
    // }


    before('load factory', async () => {
        factory = await loadAlcorFactory(factoryAddress, account2)
        console.log('factory address', factory.address)
    })

    // before('deploy factory', async () => {
    //     factory = await FactoryFixture()
    //     console.log('factory address', factory.address)
    // })

    // before('create alcor pool for call options', async () => {
    //     let [token0, token1] = await loadTokensFixture(token0Addr, token1Addr, account1)
    //     mock_alcor_pool_call_option_address = await createAlcorPoolCallOption(factory, token0, token1, optionExpiration, optionStrikePrice)

    //     console.log('mock_alcor_pool_call_option', mock_alcor_pool_call_option_address)
    // })



    // let alcorAddresses: string[] = []
    // it('pools info and getting pools addresses', async () => {
    //     let expiration = AlcorPoolsParams[0].optionExpiration
    //     let isCall: boolean = true
    //     let strikes = await factory.getStrikesForPairAndExpiration(token0Addr, token1Addr, expiration, isCall)
    //     console.log('strikes', strikes)

    //     for (let i = 0; i < strikes.length; i++) {
    //         let pools = await factory.getPool(token0Addr, token1Addr, expiration, isCall, strikes[i])
    //         console.log(strikes[i], pools)
    //         alcorAddresses.push(pools)
    //     }
    // })

    // [
    //     '0x34fD777a6E4eE74C0E636Af865db776fD1589590',
    //     '0xbE80e1641e024D02aCDf4859e3Fe12514CEe9Cff',
    //     '0x4f01c71c7ddCe811752eE17ddC21B369eb5854aB',
    //     '0x1751fc14699E27966b11B36fF477eb15Fad42e8b'
    // ]

    mock_alcor_pool_call_option_address = "0x1751fc14699E27966b11B36fF477eb15Fad42e8b"

    // for (let i = 0; i < accountsLength; i++) {
    let i = 1;
    it("approve tokens to alcor pool contract", async () => {
        let accounts = [account1, account2, account3]
        let [token0, token1] = await loadTokensFixture(token0Addr, token1Addr, accounts[i])
        // console.log('token0', token0.address)
        let tx0 = await token0.approve(mock_alcor_pool_call_option_address, BigNumber.from(2).pow(150).toString())
        await tx0.wait();
        let tx1 = await token1.approve(mock_alcor_pool_call_option_address, BigNumber.from(2).pow(150).toString())
        await tx1.wait();

        console.log('i=', i, '; tokens approved')
    })
    // }



    for (const deposit of DEPOSITS) {

        // const deposit = DEPOSITS[1]
        it(`deposit ${formatTokenAmount(deposit.amount)} of ${deposit.token}`, async () => {
            let sender: Wallet
            (deposit.owner == account1.address) ? sender = account1 : (deposit.owner == account2.address) ? sender = account2 : sender = account3
            let mock_alcor_pool_call_option: MockAlcorPoolCallOption = await loadAlcorPoolCallOptionContract(
                mock_alcor_pool_call_option_address,
                sender)
            let { token, amount } = deposit
            let tokenAddress = (token == 'token0') ? token0Addr : token1Addr
            let tx = await mock_alcor_pool_call_option.deposit(tokenAddress, amount)
            await tx.wait()
        })
    }
})