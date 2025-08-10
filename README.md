# Decentralized Poker Game

A fully on-chain, trustless poker game built on Ethereum where players can engage in poker matches without relying on any central authority or trusting other players. The game leverages blockchain technology to ensure transparency, security, and provable fairness in every hand.

## 🎮 Features

- **Fully On-Chain Gameplay**: Every action, from card dealing to betting, happens on the blockchain
- **Trustless System**: No need to trust other players or a central server—everything is verifiable
- **Smart Contract-Based Rules**: Game logic is enforced through immutable smart contracts
- **Secure Card Dealing**: Innovative cryptographic system for secure and verifiable card dealing
- **Real-time Updates**: Flutter-based UI with real-time game state updates
- **Fair Gaming**: Provably fair gameplay with all actions recorded on the blockchain

## Demo & Pitch

Our pitch deck, which includes a demo video, can be accessed [here](https://www.canva.com/design/DAGegjaThjU/_942RLOhgNFEFAwQYnpMUQ/view?utm_content=DAGegjaThjU&utm_campaign=designshare&utm_medium=link2&utm_source=uniquelinks&utlId=h4529bb1b1a).

## 🏗 Architecture

The project consists of two main components:

1. **Smart Contracts** (`/contracts`)
   - Written in Solidity
   - Handles game logic, card dealing, and betting
   - Manages player states and game progression
   - Implements cryptographic card dealing system

2. **Flutter Frontend** (`/poker_dapp`)
   - Modern, responsive UI
   - Real-time game state updates
   - Web3 wallet integration
   - Interactive betting interface

## 🎲 Game Flow

1. **Game Creation**: Any player can create a new game
2. **Joining**: Second player joins with matching buy-in
3. **Card Dealing**: First player encrypts and submits deck
4. **Card Selection**: Second player selects and verifies cards
5. **Betting Rounds**: Players participate in betting rounds
6. **Card Revelation**: Community cards revealed through decryption
7. **Showdown**: Winner determined and pot distributed

## 🔧 Technical Implementation

- **Card Dealing Security**: Uses a combination of encryption and commitment schemes
- **State Management**: Handles complex game states through smart contract events
- **Betting System**: Implements standard poker betting rules on-chain
- **Decryption Process**: Two-phase decryption for secure card revelation

## 🚀 Getting Started

### Prerequisites
- Node.js and npm
- Flutter SDK
- Hardhat
- MetaMask or similar Web3 wallet

### Installation

1. Clone the repository:
```bash
git clone [repository-url]
```

2. Install smart contract dependencies:
```bash
npm install
```

3. Install Flutter dependencies:
```bash
cd poker_dapp
flutter pub get
```

4. Start local blockchain:
```bash
npx hardhat node
```

5. Deploy contracts:
```bash
npx hardhat run scripts/deploy.js --network localhost
```

6. Run the Flutter app:
```bash
cd poker_dapp
flutter run -d chrome
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔗 Links

- [Documentation](docs/)
- [Smart Contracts](contracts/)
- [Frontend App](poker_dapp/)

## 🙏 Acknowledgments

Built during ETHOxford Hackathon 2024
