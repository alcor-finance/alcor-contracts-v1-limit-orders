import { Decimal } from 'decimal.js'
import { BigNumber, Wallet } from 'ethers'
import { ethers } from 'hardhat'
import { expect } from '../shared/expect'

import { TokenERC20 } from '../../typechain/TokenERC20'
import { AlcorFactory } from '../../typechain/AlcorFactory'
import { MockAlcorPoolCallOption } from '../../typechain/MockAlcorPoolCallOption'

import { delay, tickToPrice } from '../shared/utils'
import { formatTokenAmount } from '../shared/format'

import { mumbaiUSDC2, mumbaiWETH2 } from '../constants'
import { mumbaiFactoryAddr } from '../constants'

import {
    Tokens, deployTokensFixture,
    loadTokensFixture, FactoryFixture,
    createAlcorPoolCallOption,
    loadAlcorPoolCallOptionContract,
    loadAlcorFactory
} from '../shared/fixtures'


Decimal.config({ toExpNeg: -500, toExpPos: 500 })

const AlcorPoolsParams = [
    {
        isCallOption: true,
        optionExpiration: "1695978000",
        optionStrikePrice: ethers.utils.parseEther("2000")
    },
    {
        isCallOption: true,
        optionExpiration: "1695978000",
        optionStrikePrice: ethers.utils.parseEther("2100")
    },
    {
        isCallOption: true,
        optionExpiration: "1695978000",
        optionStrikePrice: ethers.utils.parseEther("2200")
    },
    {
        isCallOption: true,
        optionExpiration: "1695978000",
        optionStrikePrice: ethers.utils.parseEther("2300")
    },
]


describe('AlcorPoolCallOptions multipleOptions tests', () => {
    let accountsLength: number = 3
    let account1: Wallet, account2: Wallet, account3: Wallet
    let token0Addr: string, token1Addr: string
    token0Addr = mumbaiUSDC2
    token1Addr = mumbaiWETH2

    let factory: AlcorFactory
    let alcor_factory_address: string //= mumbaiFactoryAddr

    let mock_alcor_pool_call_option_address: string
    // const { isCallOption, optionExpiration, optionStrikePrice } = AlcorPoolsParams[0];

    // let loadFixture: ReturnType<typeof createFixtureLoader>
    before("load wallets", async () => {
        [account1, account2, account3] = await (ethers as any).getSigners()
        // accounts = await (ethers as any).getSigners()
        console.log(account1.address, account2.address, account3.address)
    })

    // before("deploy tokens", async () => {
    //     [token0Addr, token1Addr] = await deployTokensFixture()
    //     let deployer: Wallet = account1
    //     let [token0, token1] = await loadTokensFixture(token0Addr, token1Addr, deployer)
    //     console.log("token0:", token0.address)
    //     console.log("token1:", token1.address)
    // })
    
    // before("load factory", async () => {
    //     factory = await loadAlcorFactory(alcor_factory_address, account1);
    //     console.log('factory loaded', factory.address)
    // })

    it('deploy factory', async () => {
        factory = await FactoryFixture()
        console.log('factory address', factory.address)
    })

    for (let i = 0; i < AlcorPoolsParams.length; i++) {
        it(`${i}: create alcor pool for call options`, async () => {
            let optionExpiration = AlcorPoolsParams[i].optionExpiration
            let optionStrikePrice = AlcorPoolsParams[i].optionStrikePrice
            let [token0, token1] = await loadTokensFixture(token0Addr, token1Addr, account1)
            mock_alcor_pool_call_option_address = await createAlcorPoolCallOption(factory, token0, token1, optionExpiration, optionStrikePrice)

            console.log(`${i}) mock_alcor_pool_call_option`, mock_alcor_pool_call_option_address)

        })
    }

    it('pools info', async () => {
        let expiration = AlcorPoolsParams[0].optionExpiration
        let isCall: boolean = true
        let strikes = await factory.getStrikesForPairAndExpiration(token0Addr, token1Addr, expiration, isCall)
        console.log('strikes', strikes)

        for (let i = 0; i < strikes.length; i++) {
            let pools = await factory.getPool(token0Addr, token1Addr, expiration, isCall, strikes[i])
            console.log(strikes[i], pools)
        }
    })
})