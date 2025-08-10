const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PokerGame", function () {
    let pokerGame;
    let owner;
    let player1;
    let player2;
    const buyInAmount = ethers.parseEther("1"); // 1 ether

    beforeEach(async function () {
        // Get signers for testing
        [owner, player1, player2] = await ethers.getSigners();

        // Deploy the contract
        const PokerGame = await ethers.getContractFactory("PokerGame");
        pokerGame = await PokerGame.deploy();

        // Wait for deployment
        await pokerGame.waitForDeployment();
    });

    describe("Game Setup", function () {
        it("Should initialize with correct buy-in amount", async function () {
            const contractBuyIn = await pokerGame.buyInAmount();
            expect(contractBuyIn).to.equal(buyInAmount);
        });

        it("Should allow players to join with correct buy-in", async function () {
            await pokerGame.connect(player1).joinGame({ value: buyInAmount });
            expect(await pokerGame.isPlayerInGame(player1.address)).to.be.true;
        });

        it("Should reject join with incorrect buy-in amount", async function () {
            const wrongAmount = ethers.parseEther("0.5");
            await expect(
                pokerGame.connect(player1).joinGame({ value: wrongAmount })
            ).to.be.revertedWith("Must send exact buy-in amount");
        });

        it("Should reject player trying to join twice", async function () {
            // First join
            await pokerGame.connect(player1).joinGame({ value: buyInAmount });
            
            // Try to join again
            await expect(
                pokerGame.connect(player1).joinGame({ value: buyInAmount })
            ).to.be.revertedWith("Already in game");
        });

        it("Should emit PlayerJoined event", async function () {
            await expect(pokerGame.connect(player1).joinGame({ value: buyInAmount }))
                .to.emit(pokerGame, "PlayerJoined")
                .withArgs(player1.address);
        });

        it("Should start commit phase when second player joins", async function () {
            await pokerGame.connect(player1).joinGame({ value: buyInAmount });
            await pokerGame.connect(player2).joinGame({ value: buyInAmount });
            
            const gameState = await pokerGame.currentGame();
            expect(gameState.phase).to.equal(1); // CommitPhase
        });

        it("Should deal cards to players", async function () {
            await pokerGame.connect(player1).joinGame({ value: buyInAmount });
            await pokerGame.connect(player2).joinGame({ value: buyInAmount });
            
            const player1State = await pokerGame.players(0);
            const player2State = await pokerGame.players(1);
            
            // Check that players are active
            expect(player1State.isActive).to.be.true;
            expect(player2State.isActive).to.be.true;
            
            // Verify that the game phase changed to CommitPhase
            const gameState = await pokerGame.currentGame();
            expect(gameState.phase).to.equal(1); // CommitPhase
        });
    });

    describe("Card Dealing Flow", function () {
        beforeEach(async function () {
            await pokerGame.connect(player1).joinGame({ value: buyInAmount });
            await pokerGame.connect(player2).joinGame({ value: buyInAmount });
        });

        it("Should follow the complete poker game flow", async function () {
            // First player encrypts deck
            const encryptedDeck = Array(52).fill(0).map((_, i) => i); // Mock encrypted deck
            await pokerGame.connect(player1).submitEncryptedDeck(encryptedDeck);
            const state1 = await pokerGame.currentGame();
            expect(state1.phase).to.equal(2); // SecondPlayerCardSelection

            // Second player selects their cards
            await pokerGame.connect(player2).selectCards([0, 1]);
            const state2 = await pokerGame.currentGame();
            expect(state2.phase).to.equal(3); // FirstPlayerDecryption

            // First player decrypts second player's cards
            await pokerGame.connect(player1).decryptCards([7, 8], player2.address);
            const state3 = await pokerGame.currentGame();
            expect(state3.phase).to.equal(4); // SecondPlayerCardEncryption

            // Second player encrypts cards for first player
            await pokerGame.connect(player2).encryptCardsForFirstPlayer([2, 3]);
            const state4 = await pokerGame.currentGame();
            expect(state4.phase).to.equal(5); // FirstPlayerCardDecryption

            // First player decrypts their own cards
            await pokerGame.connect(player1).decryptCards([10, 11], player1.address);
            const state5 = await pokerGame.currentGame();
            expect(state5.phase).to.equal(6); // SecondPlayerOwnCardSelection

            // Second player selects their own cards
            await pokerGame.connect(player2).selectOwnCards([4, 5]);
            const state6 = await pokerGame.currentGame();
            expect(state6.phase).to.equal(7); // SecondPlayerDeckSort

            // Second player sorts and submits deck
            const sortedDeck = Array(52).fill(0).map((_, i) => i); // Mock sorted deck
            await pokerGame.connect(player2).submitSortedDeck(sortedDeck);
            const state7 = await pokerGame.currentGame();
            expect(state7.phase).to.equal(8); // DeckEncryption

            // Second player encrypts remaining deck
            await pokerGame.connect(player2).submitEncryptedDeck(encryptedDeck);
            const state8 = await pokerGame.currentGame();
            expect(state8.phase).to.equal(9); // PreFlopBetting

            // Pre-flop betting round
            await pokerGame.connect(player2).placeBet({ value: ethers.parseEther("0.1") });
            await pokerGame.connect(player1).placeBet({ value: ethers.parseEther("0.1") });
            const state9 = await pokerGame.currentGame();
            expect(state9.phase).to.equal(10); // FlopDealing

            // Deal flop
            await pokerGame.connect(player1).dealCommunityCards();
            const state10 = await pokerGame.currentGame();
            expect(state10.phase).to.equal(11); // FlopBetting
            expect(state10.communityCardsDealt).to.equal(3);

            // Flop betting round
            await pokerGame.connect(player2).placeBet({ value: ethers.parseEther("0.2") });
            await pokerGame.connect(player1).placeBet({ value: ethers.parseEther("0.2") });
            const state11 = await pokerGame.currentGame();
            expect(state11.phase).to.equal(12); // TurnDealing

            // Deal turn
            await pokerGame.connect(player1).dealCommunityCards();
            const state12 = await pokerGame.currentGame();
            expect(state12.phase).to.equal(13); // TurnBetting
            expect(state12.communityCardsDealt).to.equal(4);

            // Turn betting round
            await pokerGame.connect(player2).placeBet({ value: ethers.parseEther("0.3") });
            await pokerGame.connect(player1).placeBet({ value: ethers.parseEther("0.3") });
            const state13 = await pokerGame.currentGame();
            expect(state13.phase).to.equal(14); // RiverDealing

            // Deal river
            await pokerGame.connect(player1).dealCommunityCards();
            const state14 = await pokerGame.currentGame();
            expect(state14.phase).to.equal(15); // RiverBetting
            expect(state14.communityCardsDealt).to.equal(5);

            // River betting round
            await pokerGame.connect(player2).placeBet({ value: ethers.parseEther("0.4") });
            await pokerGame.connect(player1).placeBet({ value: ethers.parseEther("0.4") });
            const state15 = await pokerGame.currentGame();
            expect(state15.phase).to.equal(16); // ShowDown
        });

        it("Should allow folding at any betting phase", async function () {
            // Setup game until betting starts
            const encryptedDeck = Array(52).fill(0).map((_, i) => i);
            await pokerGame.connect(player1).submitEncryptedDeck(encryptedDeck);
            await pokerGame.connect(player2).selectCards([0, 1]);
            await pokerGame.connect(player1).decryptCards([7, 8], player2.address);
            await pokerGame.connect(player2).encryptCardsForFirstPlayer([2, 3]);
            await pokerGame.connect(player1).decryptCards([10, 11], player1.address);
            await pokerGame.connect(player2).selectOwnCards([4, 5]);
            await pokerGame.connect(player2).submitSortedDeck(encryptedDeck);
            await pokerGame.connect(player2).submitEncryptedDeck(encryptedDeck);

            // Pre-flop betting
            await pokerGame.connect(player2).placeBet({ value: ethers.parseEther("0.1") });
            await pokerGame.connect(player1).fold();

            // Check that game ended
            const gameState = await pokerGame.currentGame();
            expect(gameState.phase).to.equal(0); // Back to Joining
            expect(gameState.pot).to.equal(0);
            expect(gameState.currentBet).to.equal(0);
            expect(gameState.communityCardsDealt).to.equal(0);
        });

        it("Should prevent wrong player actions", async function () {
            const encryptedDeck = Array(52).fill(0).map((_, i) => i);
            
            // Second player can't encrypt first
            await expect(
                pokerGame.connect(player2).submitEncryptedDeck(encryptedDeck)
            ).to.be.revertedWith("Not first player");

            // First player encrypts deck
            await pokerGame.connect(player1).submitEncryptedDeck(encryptedDeck);

            // First player can't select cards in second player's turn
            await expect(
                pokerGame.connect(player1).selectCards([0, 1])
            ).to.be.revertedWith("Not second player");

            // Complete flow until second player's own card selection
            await pokerGame.connect(player2).selectCards([0, 1]);
            await pokerGame.connect(player1).decryptCards([7, 8], player2.address);
            await pokerGame.connect(player2).encryptCardsForFirstPlayer([2, 3]);
            await pokerGame.connect(player1).decryptCards([10, 11], player1.address);

            // First player can't select own cards in second player's turn
            await expect(
                pokerGame.connect(player1).selectOwnCards([4, 5])
            ).to.be.revertedWith("Not second player");
        });
    });
}); 