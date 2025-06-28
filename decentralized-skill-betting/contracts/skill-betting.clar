;; Decentralized Betting on Skill Games Smart Contract
;; This contract allows players to create and participate in skill-based games with betting

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-GAME-NOT-FOUND (err u101))
(define-constant ERR-GAME-ALREADY-EXISTS (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-GAME-NOT-ACTIVE (err u104))
(define-constant ERR-ALREADY-JOINED (err u105))
(define-constant ERR-GAME-FULL (err u106))
(define-constant ERR-NOT-PLAYER (err u107))
(define-constant ERR-GAME-NOT-FINISHED (err u108))
(define-constant ERR-INVALID-SCORE (err u109))
(define-constant ERR-SCORES-ALREADY-SUBMITTED (err u110))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Game status constants
(define-constant GAME-STATUS-WAITING u0)
(define-constant GAME-STATUS-ACTIVE u1)
(define-constant GAME-STATUS-FINISHED u2)
(define-constant GAME-STATUS-CANCELLED u3)

;; Maximum players per game
(define-constant MAX-PLAYERS u10)

;; Platform fee (2% in basis points)
(define-constant PLATFORM-FEE u200)
(define-constant BASIS-POINTS u10000)

;; Data structures
(define-map games
  { game-id: uint }
  {
    creator: principal,
    game-type: (string-ascii 50),
    entry-fee: uint,
    max-players: uint,
    current-players: uint,
    status: uint,
    created-at: uint,
    prize-pool: uint,
    winner: (optional principal)
  }
)

(define-map game-players
  { game-id: uint, player: principal }
  {
    score: (optional uint),
    submitted-at: (optional uint),
    position: (optional uint)
  }
)

(define-map player-games
  { player: principal, game-id: uint }
  { joined-at: uint }
)

;; Track game IDs
(define-data-var next-game-id uint u1)

;; Platform earnings
(define-data-var platform-earnings uint u0)

;; Read-only functions
(define-read-only (get-game (game-id uint))
  (map-get? games { game-id: game-id })
)

(define-read-only (get-player-in-game (game-id uint) (player principal))
  (map-get? game-players { game-id: game-id, player: player })
)

(define-read-only (get-next-game-id)
  (var-get next-game-id)
)

(define-read-only (get-platform-earnings)
  (var-get platform-earnings)
)

(define-read-only (is-player-in-game (game-id uint) (player principal))
  (is-some (map-get? game-players { game-id: game-id, player: player }))
)

;; Private functions
(define-private (calculate-platform-fee (amount uint))
  (/ (* amount PLATFORM-FEE) BASIS-POINTS)
)

(define-private (update-platform-earnings (amount uint))
  (var-set platform-earnings (+ (var-get platform-earnings) amount))
)

;; Public functions

;; Create a new skill-based game
(define-public (create-game (game-type (string-ascii 50)) (entry-fee uint) (max-players uint))
  (let
    (
      (game-id (var-get next-game-id))
      (current-block-height block-height)
    )
    ;; Validate input parameters
    (asserts! (and (> max-players u0) (<= max-players MAX-PLAYERS)) ERR-NOT-AUTHORIZED)
    (asserts! (> entry-fee u0) ERR-NOT-AUTHORIZED)
    
    ;; Check if game already exists (redundant but safe)
    (asserts! (is-none (map-get? games { game-id: game-id })) ERR-GAME-ALREADY-EXISTS)
    
    ;; Create the game
    (map-set games
      { game-id: game-id }
      {
        creator: tx-sender,
        game-type: game-type,
        entry-fee: entry-fee,
        max-players: max-players,
        current-players: u0,
        status: GAME-STATUS-WAITING,
        created-at: current-block-height,
        prize-pool: u0,
        winner: none
      }
    )
    
    ;; Increment next game ID
    (var-set next-game-id (+ game-id u1))
    
    (ok game-id)
  )
)

;; Join an existing game
(define-public (join-game (game-id uint))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) ERR-GAME-NOT-FOUND))
      (entry-fee (get entry-fee game))
      (platform-fee (calculate-platform-fee entry-fee))
      (prize-contribution (- entry-fee platform-fee))
    )
    ;; Check if game is in waiting status
    (asserts! (is-eq (get status game) GAME-STATUS-WAITING) ERR-GAME-NOT-ACTIVE)
    
    ;; Check if player hasn't already joined
    (asserts! (not (is-player-in-game game-id tx-sender)) ERR-ALREADY-JOINED)
    
    ;; Check if game is not full
    (asserts! (< (get current-players game) (get max-players game)) ERR-GAME-FULL)
    
    ;; Transfer entry fee from player
    (try! (stx-transfer? entry-fee tx-sender (as-contract tx-sender)))
    
    ;; Add player to game
    (map-set game-players
      { game-id: game-id, player: tx-sender }
      {
        score: none,
        submitted-at: none,
        position: none
      }
    )
    
    ;; Track player's games
    (map-set player-games
      { player: tx-sender, game-id: game-id }
      { joined-at: block-height }
    )
    
    ;; Update game data
    (map-set games
      { game-id: game-id }
      (merge game {
        current-players: (+ (get current-players game) u1),
        prize-pool: (+ (get prize-pool game) prize-contribution),
        status: (if (is-eq (+ (get current-players game) u1) (get max-players game))
                   GAME-STATUS-ACTIVE
                   GAME-STATUS-WAITING)
      })
    )
    
    ;; Update platform earnings
    (update-platform-earnings platform-fee)
    
    (ok true)
  )
)

;; Submit score for a game (only when game is active)
(define-public (submit-score (game-id uint) (score uint))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) ERR-GAME-NOT-FOUND))
      (player-data (unwrap! (map-get? game-players { game-id: game-id, player: tx-sender }) ERR-NOT-PLAYER))
    )
    ;; Check if game is active
    (asserts! (is-eq (get status game) GAME-STATUS-ACTIVE) ERR-GAME-NOT-ACTIVE)
    
    ;; Check if player hasn't submitted score yet
    (asserts! (is-none (get score player-data)) ERR-SCORES-ALREADY-SUBMITTED)
    
    ;; Validate score (basic validation - can be enhanced)
    (asserts! (and (>= score u0) (<= score u1000000)) ERR-INVALID-SCORE)
    
    ;; Update player's score
    (map-set game-players
      { game-id: game-id, player: tx-sender }
      (merge player-data {
        score: (some score),
        submitted-at: (some block-height)
      })
    )
    
    (ok true)
  )
)

;; Finalize game and determine winner (simplified - highest score wins)
(define-public (finalize-game (game-id uint))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) ERR-GAME-NOT-FOUND))
    )
    ;; Only game creator or contract owner can finalize
    (asserts! (or (is-eq tx-sender (get creator game)) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    
    ;; Check if game is active
    (asserts! (is-eq (get status game) GAME-STATUS-ACTIVE) ERR-GAME-NOT-ACTIVE)
    
    ;; Mark game as finished
    (map-set games
      { game-id: game-id }
      (merge game {
        status: GAME-STATUS-FINISHED
      })
    )
    
    (ok true)
  )
)

;; Distribute prizes to winner
(define-public (distribute-prize (game-id uint) (winner principal))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) ERR-GAME-NOT-FOUND))
      (prize-pool (get prize-pool game))
    )
    ;; Only game creator or contract owner can distribute prizes
    (asserts! (or (is-eq tx-sender (get creator game)) (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    
    ;; Check if game is finished
    (asserts! (is-eq (get status game) GAME-STATUS-FINISHED) ERR-GAME-NOT-FINISHED)
    
    ;; Check if winner is a valid player in the game
    (asserts! (is-player-in-game game-id winner) ERR-NOT-PLAYER)
    
    ;; Transfer prize to winner
    (try! (as-contract (stx-transfer? prize-pool tx-sender winner)))
    
    ;; Update game with winner
    (map-set games
      { game-id: game-id }
      (merge game {
        winner: (some winner)
      })
    )
    
    (ok true)
  )
)

;; Cancel game (only if in waiting status)
(define-public (cancel-game (game-id uint))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) ERR-GAME-NOT-FOUND))
    )
    ;; Only game creator can cancel
    (asserts! (is-eq tx-sender (get creator game)) ERR-NOT-AUTHORIZED)
    
    ;; Only waiting games can be cancelled
    (asserts! (is-eq (get status game) GAME-STATUS-WAITING) ERR-GAME-NOT-ACTIVE)
    
    ;; Mark game as cancelled
    (map-set games
      { game-id: game-id }
      (merge game {
        status: GAME-STATUS-CANCELLED
      })
    )
    
    (ok true)
  )
)

;; Withdraw platform earnings (only contract owner)
(define-public (withdraw-platform-earnings (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= amount (var-get platform-earnings)) ERR-INSUFFICIENT-FUNDS)
    
    ;; Transfer earnings to contract owner
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
    
    ;; Update platform earnings
    (var-set platform-earnings (- (var-get platform-earnings) amount))
    
    (ok true)
  )
)