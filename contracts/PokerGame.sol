// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PokerGame {
    struct Player {
        address addr;
        uint256 chips;
        bool isActive;
        uint8[2] hand;
        bool hasCommitted;
        bool hasRevealed;
    }

    struct GameState {
        uint8[5] communityCards;      // Community cards
        uint256 pot;                  // Current pot
        uint256 currentBet;           // Current bet amount
        uint8 currentPlayer;          // Current player (0 for first, 1 for second)
        uint256 roundDeadline;        // Deadline for current round
        GamePhase phase;              // Current game phase
        address firstPlayer;          // Address of first player
        uint256 lastBetAmount;        // Amount of last bet
        uint8 communityCardsDealt;    // Number of community cards dealt
        uint8 numPlayers;             // Number of players in game
        uint256[] encryptedDeck;      // Encrypted deck from first player
        uint8[2] firstPlayerCards;    // Cards for first player
        uint8[2] secondPlayerCards;   // Encrypted cards for second player
        uint8[5] encryptedFlopCards;  // Selected flop cards
        uint256 encryptionSeed;       // Encryption seed for second player
        Player[] players;             // Array of players in the game
        mapping(address => uint256) bets;
        mapping(address => bool) hasDecryptedFlop;  // Track who has decrypted flop
        mapping(address => bool) hasDecryptedTurn;  // Track who has decrypted turn
        mapping(address => bool) hasDecryptedRiver; // Track who has decrypted river
    }

    enum GamePhase {
        Joining,                // Players can join the game
        FirstPlayerEncryption,  // First player encrypts and submits the deck
        SecondPlayerSelection,  // Second player selects cards
        PreFlopBetting,        // Pre-flop betting round
        FlopDecryption,        // Both players decrypt flop cards
        FlopBetting,           // Flop betting round
        TurnDecryption,        // Both players decrypt turn card
        TurnBetting,           // Turn betting round
        RiverDecryption,       // Both players decrypt river card
        RiverBetting,          // River betting round
        Showdown              // Show cards and determine winner
    }

    mapping(uint256 => GameState) public games;
    uint256 public currentGameId;
    uint256 public constant TURN_TIME = 5 minutes;
    uint256 public buyInAmount = 1 ether;
    uint8 public constant MAX_PLAYERS = 2;
    
    mapping(address => uint256) public playerGameId; // Track which game a player is in

    event GameCreated(uint256 gameId);
    event PlayerJoined(uint256 gameId, address player);
    event NewRound(uint256 gameId, uint256 timestamp);
    event PlayerBet(uint256 gameId, address player, uint256 amount);
    event PlayerFolded(uint256 gameId, address player);
    event DeckEncrypted(uint256 gameId, address player);
    event CardsSelected(uint256 gameId, address player);
    event CardsDecrypted(uint256 gameId, address player);
    event CommunityCardsDealt(uint256 gameId, uint8 count);
    event DeckSorted(uint256 gameId, address player);

    constructor() {
        currentGameId = 0;
        createNewGame();
    }

    function createNewGame() public {
        currentGameId++;
        games[currentGameId].phase = GamePhase.Joining;
        emit GameCreated(currentGameId);
    }

    function joinGame(uint256 gameId) external payable {
        require(msg.value == buyInAmount, "Must send exact buy-in amount");
        require(games[gameId].players.length < MAX_PLAYERS, "Game is full");
        require(!isPlayerInGame(msg.sender), "Already in a game");
        require(games[gameId].phase == GamePhase.Joining, "Game in progress");

        Player memory newPlayer = Player({
            addr: msg.sender,
            chips: msg.value,
            isActive: true,
            hand: [0, 0],
            hasCommitted: false,
            hasRevealed: false
        });

        games[gameId].players.push(newPlayer);
        playerGameId[msg.sender] = gameId;

        if (games[gameId].players.length == 1) {
            games[gameId].firstPlayer = msg.sender;
        }

        emit PlayerJoined(gameId, msg.sender);

        if (games[gameId].players.length == MAX_PLAYERS) {
            games[gameId].phase = GamePhase.FirstPlayerEncryption;
            if (games[gameId].players.length == MAX_PLAYERS && gameId == currentGameId) {
                createNewGame();
            }
        }
    }

    function getCurrentGameId() external view returns (uint256) {
        return currentGameId;
    }

    function getPlayerGameId(address player) external view returns (uint256) {
        return playerGameId[player];
    }

    function isPlayerInGame(address playerAddress) public view returns (bool) {
        uint256 gameId = playerGameId[playerAddress];
        if (gameId == 0) return false;
        
        for (uint i = 0; i < games[gameId].players.length; i++) {
            if (games[gameId].players[i].addr == playerAddress) {
                return true;
            }
        }
        return false;
    }

    function selectCards(
        uint256 gameId,
        uint8[2] memory _firstPlayerCards,
        uint8[2] memory _secondPlayerCards,
        uint8[5] memory _flopCards,
        uint256 _encryptionSeed
    ) external {
        require(isPlayerInGame(msg.sender), "Not in game");
        require(playerGameId[msg.sender] == gameId, "Not in this game");
        require(games[gameId].phase == GamePhase.SecondPlayerSelection, "Wrong phase");
        require(msg.sender != games[gameId].firstPlayer, "Not second player");
        require(games[gameId].encryptedDeck.length == 52, "No encrypted deck available");

        // Verify that selected cards are from the encrypted deck
        for(uint8 i = 0; i < 2; i++) {
            bool foundFirst = false;
            bool foundSecond = false;
            for(uint8 j = 0; j < 52; j++) {
                if(uint8(games[gameId].encryptedDeck[j]) == _firstPlayerCards[i]) foundFirst = true;
                if(uint8(games[gameId].encryptedDeck[j]) == _secondPlayerCards[i]) foundSecond = true;
            }
            require(foundFirst && foundSecond, "Selected cards not in encrypted deck");
        }

        for(uint8 i = 0; i < 5; i++) {
            bool foundFlop = false;
            for(uint8 j = 0; j < 52; j++) {
                if(uint8(games[gameId].encryptedDeck[j]) == _flopCards[i]) foundFlop = true;
            }
            require(foundFlop, "Selected flop card not in encrypted deck");
        }

        games[gameId].firstPlayerCards = _firstPlayerCards;
        games[gameId].secondPlayerCards = _secondPlayerCards;
        games[gameId].encryptedFlopCards = _flopCards;
        games[gameId].encryptionSeed = _encryptionSeed;
        games[gameId].phase = GamePhase.PreFlopBetting;
        games[gameId].currentPlayer = 1; // Second player starts betting
        
        emit CardsSelected(gameId, msg.sender);
    }

    function submitEncryptedDeck(uint256 gameId, uint256[] calldata _encryptedDeck) external {
        require(isPlayerInGame(msg.sender), "Not in game");
        require(playerGameId[msg.sender] == gameId, "Not in this game");
        require(
            games[gameId].phase == GamePhase.FirstPlayerEncryption,
            "Wrong phase"
        );
        require(msg.sender == games[gameId].firstPlayer, "Not first player");
        require(_encryptedDeck.length == 52, "Invalid deck size");

        games[gameId].encryptedDeck = _encryptedDeck;
        games[gameId].phase = GamePhase.SecondPlayerSelection;
        
        emit DeckEncrypted(gameId, msg.sender);
    }

    function decryptCards(uint8[2] memory decryptedCards, address forPlayer) public {
        uint256 gameId = playerGameId[msg.sender];
        require(gameId > 0, "Not in a game");
        require(
            (games[gameId].phase == GamePhase.PreFlopBetting && forPlayer != games[gameId].firstPlayer) ||
            (games[gameId].phase == GamePhase.FlopDecryption && forPlayer == games[gameId].firstPlayer),
            "Wrong phase or player"
        );
        
        Player storage targetPlayer = getPlayer(gameId, forPlayer);
        targetPlayer.hand = decryptedCards;
        
        if (games[gameId].phase == GamePhase.PreFlopBetting) {
            games[gameId].phase = GamePhase.FlopDecryption;
        } else {
            games[gameId].phase = GamePhase.TurnDecryption;
        }
        
        emit CardsDecrypted(gameId, msg.sender);
    }

    function selectOwnCards(uint256 gameId, uint8[2] calldata _selectedIndices) external {
        require(isPlayerInGame(msg.sender), "Not in game");
        require(playerGameId[msg.sender] == gameId, "Not in this game");
        require(games[gameId].phase == GamePhase.SecondPlayerSelection, "Wrong phase");
        require(msg.sender != games[gameId].firstPlayer, "Not second player");

        games[gameId].secondPlayerCards = _selectedIndices;
        games[gameId].phase = GamePhase.PreFlopBetting;
        games[gameId].currentPlayer = 1; // Second player starts betting
        
        emit CardsSelected(gameId, msg.sender);
    }

    function submitSortedDeck(uint256 gameId, uint8[52] calldata _sortedDeck) external {
        require(isPlayerInGame(msg.sender), "Not in game");
        require(playerGameId[msg.sender] == gameId, "Not in this game");
        require(games[gameId].phase == GamePhase.SecondPlayerSelection, "Wrong phase");
        require(msg.sender != games[gameId].firstPlayer, "Not second player");

        // Store the sorted deck and move to betting phase
        games[gameId].phase = GamePhase.PreFlopBetting;
        games[gameId].currentPlayer = 1; // Second player starts betting
        
        emit DeckSorted(gameId, msg.sender);
    }

    function dealCommunityCards(uint256 gameId) external {
        require(isPlayerInGame(msg.sender), "Not in game");
        require(playerGameId[msg.sender] == gameId, "Not in this game");
        require(msg.sender == games[gameId].firstPlayer, "Not first player");
        require(
            games[gameId].phase == GamePhase.FlopDecryption ||
            games[gameId].phase == GamePhase.TurnDecryption ||
            games[gameId].phase == GamePhase.RiverDecryption,
            "Not decryption phase"
        );

        // Update game phase based on current phase
        if (games[gameId].phase == GamePhase.FlopDecryption) {
            games[gameId].phase = GamePhase.FlopBetting;
            games[gameId].communityCardsDealt = 3;
        } else if (games[gameId].phase == GamePhase.TurnDecryption) {
            games[gameId].phase = GamePhase.TurnBetting;
            games[gameId].communityCardsDealt = 4;
        } else if (games[gameId].phase == GamePhase.RiverDecryption) {
            games[gameId].phase = GamePhase.RiverBetting;
            games[gameId].communityCardsDealt = 5;
        }
        
        emit CommunityCardsDealt(gameId, games[gameId].communityCardsDealt);
    }

    function decryptCommunityCards(uint256 gameId, uint8[] memory decryptedCards) external {
        require(isPlayerInGame(msg.sender), "Not in game");
        require(playerGameId[msg.sender] == gameId, "Not in this game");
        require(
            games[gameId].phase == GamePhase.FlopDecryption ||
            games[gameId].phase == GamePhase.TurnDecryption ||
            games[gameId].phase == GamePhase.RiverDecryption,
            "Not decryption phase"
        );

        // Store decrypted cards based on the phase
        if (games[gameId].phase == GamePhase.FlopDecryption) {
            require(decryptedCards.length == 3, "Invalid flop cards count");
            require(!games[gameId].hasDecryptedFlop[msg.sender], "Already decrypted flop");
            if (msg.sender == games[gameId].firstPlayer) {
                for(uint8 i = 0; i < 3; i++) {
                    games[gameId].communityCards[i] = decryptedCards[i];
                }
            }
            games[gameId].hasDecryptedFlop[msg.sender] = true;
        } else if (games[gameId].phase == GamePhase.TurnDecryption) {
            require(decryptedCards.length == 1, "Invalid turn card count");
            require(!games[gameId].hasDecryptedTurn[msg.sender], "Already decrypted turn");
            if (msg.sender == games[gameId].firstPlayer) {
                games[gameId].communityCards[3] = decryptedCards[0];
            }
            games[gameId].hasDecryptedTurn[msg.sender] = true;
        } else if (games[gameId].phase == GamePhase.RiverDecryption) {
            require(decryptedCards.length == 1, "Invalid river card count");
            require(!games[gameId].hasDecryptedRiver[msg.sender], "Already decrypted river");
            if (msg.sender == games[gameId].firstPlayer) {
                games[gameId].communityCards[4] = decryptedCards[0];
            }
            games[gameId].hasDecryptedRiver[msg.sender] = true;
        }

        // Check if both players have decrypted
        bool bothDecrypted = false;
        if (games[gameId].phase == GamePhase.FlopDecryption) {
            bothDecrypted = games[gameId].hasDecryptedFlop[games[gameId].firstPlayer] &&
                           games[gameId].hasDecryptedFlop[games[gameId].players[1].addr];
            if (bothDecrypted) {
                games[gameId].communityCardsDealt = 3;
            }
        } else if (games[gameId].phase == GamePhase.TurnDecryption) {
            bothDecrypted = games[gameId].hasDecryptedTurn[games[gameId].firstPlayer] &&
                           games[gameId].hasDecryptedTurn[games[gameId].players[1].addr];
            if (bothDecrypted) {
                games[gameId].communityCardsDealt = 4;
            }
        } else if (games[gameId].phase == GamePhase.RiverDecryption) {
            bothDecrypted = games[gameId].hasDecryptedRiver[games[gameId].firstPlayer] &&
                           games[gameId].hasDecryptedRiver[games[gameId].players[1].addr];
            if (bothDecrypted) {
                games[gameId].communityCardsDealt = 5;
            }
        }

        // Move to betting phase after both players have decrypted
        if (bothDecrypted) {
            if (games[gameId].phase == GamePhase.FlopDecryption) {
                games[gameId].phase = GamePhase.FlopBetting;
            } else if (games[gameId].phase == GamePhase.TurnDecryption) {
                games[gameId].phase = GamePhase.TurnBetting;
            } else if (games[gameId].phase == GamePhase.RiverDecryption) {
                games[gameId].phase = GamePhase.RiverBetting;
            }
            games[gameId].currentPlayer = 1; // Second player starts betting
            games[gameId].currentBet = 0;
        }
        
        emit CardsDecrypted(gameId, msg.sender);
    }

    function placeBet(uint256 gameId) external payable {
        require(isPlayerInGame(msg.sender), "Not in game");
        require(playerGameId[msg.sender] == gameId, "Not in this game");
        require(
            games[gameId].phase == GamePhase.PreFlopBetting ||
            games[gameId].phase == GamePhase.FlopBetting ||
            games[gameId].phase == GamePhase.TurnBetting ||
            games[gameId].phase == GamePhase.RiverBetting,
            "Not betting phase"
        );
        require(msg.value >= games[gameId].currentBet, "Bet too small");

        games[gameId].bets[msg.sender] += msg.value;
        games[gameId].pot += msg.value;
        games[gameId].currentBet = msg.value;
        games[gameId].lastBetAmount = msg.value;

        // Move to next player or next round
        games[gameId].currentPlayer = uint8((uint256(games[gameId].currentPlayer) + 1) % games[gameId].players.length);
        
        // If we're back to the first better and bets are equal, move to next phase
        if (games[gameId].currentPlayer == 1 && areBetsEqual(gameId)) {
            moveToNextPhase(gameId);
        }
        
        emit PlayerBet(gameId, msg.sender, msg.value);
    }

    function fold(uint256 gameId) external {
        require(isPlayerInGame(msg.sender), "Not in game");
        require(playerGameId[msg.sender] == gameId, "Not in this game");
        require(
            games[gameId].phase == GamePhase.PreFlopBetting ||
            games[gameId].phase == GamePhase.FlopBetting ||
            games[gameId].phase == GamePhase.TurnBetting ||
            games[gameId].phase == GamePhase.RiverBetting,
            "Not betting phase"
        );

        getPlayer(gameId, msg.sender).isActive = false;
        emit PlayerFolded(gameId, msg.sender);

        if (getActivePlayerCount(gameId) == 1) {
            endRound(gameId);
        }
    }

    function encryptCards(uint256 gameId, uint8[2] calldata _encryptedCards) external {
        require(isPlayerInGame(msg.sender), "Not in game");
        require(playerGameId[msg.sender] == gameId, "Not in this game");
        require(games[gameId].phase == GamePhase.SecondPlayerSelection, "Wrong phase");
        require(msg.sender != games[gameId].firstPlayer, "Not second player");

        games[gameId].secondPlayerCards = _encryptedCards;
        games[gameId].phase = GamePhase.PreFlopBetting;
        games[gameId].currentPlayer = 1; // Second player starts betting
        
        emit CardsSelected(gameId, msg.sender);
    }

    // Helper functions
    function getPlayer(uint256 gameId, address playerAddress) private view returns (Player storage) {
        for (uint i = 0; i < games[gameId].players.length; i++) {
            if (games[gameId].players[i].addr == playerAddress) {
                return games[gameId].players[i];
            }
        }
        revert("Player not found");
    }

    function getActivePlayerCount(uint256 gameId) private view returns (uint256) {
        uint256 count = 0;
        for (uint i = 0; i < games[gameId].players.length; i++) {
            if (games[gameId].players[i].isActive) {
                count++;
            }
        }
        return count;
    }

    function endRound(uint256 gameId) private {
        // For now, just reset the game state
        resetGame(gameId);
    }

    function areBetsEqual(uint256 gameId) private view returns (bool) {
        uint256 firstBet = games[gameId].bets[games[gameId].players[0].addr];
        uint256 secondBet = games[gameId].bets[games[gameId].players[1].addr];
        return firstBet == secondBet;
    }

    function moveToNextPhase(uint256 gameId) private {
        if (games[gameId].phase == GamePhase.PreFlopBetting) {
            games[gameId].phase = GamePhase.FlopDecryption;
        } else if (games[gameId].phase == GamePhase.FlopBetting) {
            games[gameId].phase = GamePhase.TurnDecryption;
        } else if (games[gameId].phase == GamePhase.TurnBetting) {
            games[gameId].phase = GamePhase.RiverDecryption;
        } else if (games[gameId].phase == GamePhase.RiverBetting) {
            games[gameId].phase = GamePhase.Showdown;
        }
        games[gameId].currentBet = 0;
        games[gameId].lastBetAmount = 0;
    }

    function getGameBasicState(uint256 gameId) external view returns (
        uint256 pot,
        uint256 currentBet,
        uint8 currentPlayer,
        uint256 roundDeadline,
        GamePhase phase,
        address firstPlayer,
        uint256 lastBetAmount,
        uint8 communityCardsDealt,
        uint8 numPlayers
    ) {
        GameState storage game = games[gameId];
        return (
            game.pot,
            game.currentBet,
            game.currentPlayer,
            game.roundDeadline,
            game.phase,
            game.firstPlayer,
            game.lastBetAmount,
            game.communityCardsDealt,
            uint8(game.players.length)
        );
    }

    function getGameCommunityCards(uint256 gameId) external view returns (uint256[] memory) {
        GameState storage game = games[gameId];
        uint256[] memory commCards = new uint256[](5);
        for(uint8 i = 0; i < 5; i++) {
            commCards[i] = uint256(game.communityCards[i]);
        }
        return commCards;
    }

    function getGamePlayerCards(uint256 gameId) external view returns (
        uint256[] memory firstPlayerCards,
        uint256[] memory secondPlayerCards
    ) {
        GameState storage game = games[gameId];
        uint256[] memory firstCards = new uint256[](2);
        uint256[] memory secondCards = new uint256[](2);
        
        for(uint8 i = 0; i < 2; i++) {
            firstCards[i] = uint256(game.firstPlayerCards[i]);
            secondCards[i] = uint256(game.secondPlayerCards[i]);
        }
        return (firstCards, secondCards);
    }

    function getGameEncryptedDeck(uint256 gameId) external view returns (uint256[] memory) {
        GameState storage game = games[gameId];
        if (game.encryptedDeck.length > 0) {
            uint256[] memory encryptedDeckCopy = new uint256[](game.encryptedDeck.length);
            for(uint256 i = 0; i < game.encryptedDeck.length; i++) {
                encryptedDeckCopy[i] = game.encryptedDeck[i];
            }
            return encryptedDeckCopy;
        }
        return new uint256[](0);
    }

    function getGameFlopCards(uint256 gameId) external view returns (uint256[] memory) {
        GameState storage game = games[gameId];
        uint256[] memory flopCards = new uint256[](5);
        for(uint8 i = 0; i < 5; i++) {
            flopCards[i] = uint256(game.encryptedFlopCards[i]);
        }
        return flopCards;
    }

    function isFirstPlayer(address player) public view returns (bool) {
        uint256 gameId = playerGameId[player];
        if (gameId == 0) return false;
        return games[gameId].firstPlayer == player;
    }

    function getNumberOfPlayers(uint256 gameId) public view returns (uint256) {
        return games[gameId].players.length;
    }

    function resetGame(uint256 gameId) internal {
        games[gameId].pot = 0;
        games[gameId].currentBet = 0;
        games[gameId].currentPlayer = 0;
        games[gameId].phase = GamePhase.Joining;
        games[gameId].lastBetAmount = 0;
        games[gameId].communityCardsDealt = 0;
        for(uint8 i = 0; i < 5; i++) {
            games[gameId].communityCards[i] = 0;
        }
        delete games[gameId].encryptedDeck;
        delete games[gameId].firstPlayerCards;
        delete games[gameId].secondPlayerCards;
        delete games[gameId].encryptedFlopCards;
        games[gameId].encryptionSeed = 0;
        
        // Reset decryption status
        games[gameId].hasDecryptedFlop[games[gameId].firstPlayer] = false;
        games[gameId].hasDecryptedFlop[games[gameId].players[1].addr] = false;
        games[gameId].hasDecryptedTurn[games[gameId].firstPlayer] = false;
        games[gameId].hasDecryptedTurn[games[gameId].players[1].addr] = false;
        games[gameId].hasDecryptedRiver[games[gameId].firstPlayer] = false;
        games[gameId].hasDecryptedRiver[games[gameId].players[1].addr] = false;
    }
}