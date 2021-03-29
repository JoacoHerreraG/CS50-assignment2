PlayState = Class{__includes = BaseState}

function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.balls = params.balls
    self.level = params.level

    self.powerup = Powerup()
    self.ballsInPlay = 1

    self.recoverPoints = self.score + 5000
    self.sizeChangePoins = self.score + 4000
    self.keyCountdown = 15

    for ballsInPlay, ball in pairs(self.balls) do
        ball.dx = math.random(-200, 200)
        ball.dy = math.random(-50, -60)
    end
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    self.paddle:update(dt)
    for i, ball in pairs(self.balls) do
        ball:update(dt)
    end

    for i, ball in pairs(self.balls) do
        if ball:collides(self.paddle)  then
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy

            -- tweak angle of bounce based on where it hits the paddle
            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end
    end


    for k, brick in pairs(self.bricks) do

        for i, ball in pairs(self.balls) do

            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then

                if self.powerup.spawned == false then
                    -- substract 1 from the powerup spawn counter
                    self.powerup.spawnCounter = self.powerup.spawnCounter - 1
                    -- if spawnCounter reaches 0, reset the counter and spawn a powerup at the brick's position
                    if self.powerup.spawnCounter == 0 then
                        self.powerup.spawnCounter = math.random(5, 10)
                        if self.ballsInPlay == 1 then
                            self.powerup.spawned = true
                            self.powerup.x = brick.x
                            self.powerup.y = brick.y
                            self.powerup.type = 1
                        end
                    end

                    self.keyCountdown = self.keyCountdown - 1
                    if self.keyCountdown <= 0 then
                        self.powerup.spawned = true
                        self.powerup.x = brick.x
                        self.powerup.y = brick.y
                        self.powerup.type = 4
                    end
                end
                
                if brick.locked == 0 then
                    if brick.color == 6 then 
                        self.score = self.score + 2000
                    else
                        self.score = self.score + (brick.tier * 200 + brick.color * 25)
                    end
                end

                if brick.locked == 0 then
                    brick:hit()
                end

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    self.health = math.min(3, self.health + 1)

                    self.recoverPoints = self.recoverPoints + 5000

                    gSounds['recover']:play()
                end

                -- if we have enough points, increase the paddle size
                if self.score > self.sizeChangePoins then
                    self.paddle.size = math.min(4, self.paddle.size + 1)
                    self.paddle.width = 32 * self.paddle.size
                    self.sizeChangePoins = self.sizeChangePoins + 4000
                end

                if self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        balls = self.balls,
                        recoverPoints = self.recoverPoints
                    })
                end

                -- collision code for bricks
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8
                
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32
                
                elseif ball.y < brick.y then
                    
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8
                
                else
                    
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                break
            end
        end
    end

    for i, ball in pairs (self.balls) do
        if ball.y > VIRTUAL_HEIGHT then
            
            ball.y = VIRTUAL_HEIGHT
            ball.dx = 0
            ball.dy = 0
            self.ballsInPlay = self.ballsInPlay - 1
            if self.ballsInPlay == 0 then 
                self.health = self.health - 1
                self.paddle.size = math.max(1, self.paddle.size - 1)
                self.paddle.width = 32 * self.paddle.size
                gSounds['hurt']:play()
            

                if self.health == 0 then
                    gStateMachine:change('game-over', {
                        score = self.score,
                        highScores = self.highScores
                    })
                else
                    gStateMachine:change('serve', {
                        paddle = self.paddle,
                        bricks = self.bricks,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        level = self.level,
                        recoverPoints = self.recoverPoints
                    })
                end
            end
        end
    end


    if self.powerup.spawned then
        self.powerup:update(dt)
        
        if self.powerup.type == 1 then
            -- if type is 1, the powerup is the 'ball' one
            -- if player 'grabs' the powerup, spawn two new balls
            if self.powerup:collides(self.paddle) and self.ballsInPlay == 1 then
                self.powerup.spawned = false
                self.ballsInPlay = 3

                for x = 1, 2 do
                    b = Ball()
                    b.skin = math.random(7)
                    b.x = math.random(10, VIRTUAL_WIDTH - 18)
                    b.y = self.paddle.y - 8
                    b.dx = math.random(-200, 200)
                    b.dy = math.random(-50, -60)
                    table.insert(self.balls, b)
                end
            end
        else
            --if type is not 1, the powerup is the 'key' one
            if self.powerup:collides(self.paddle) then
                self.powerup.spawned = false
                self.keyCountdown = 1000
                for i, brick in pairs(self.bricks) do
                    if brick.locked == 1 then
                        brick.locked = 0
                        brick.tier = 0
                        brick.color = 6
                    end
                end
            end
        end

        -- despawn the powerup if it leaves the screen
        if self.powerup.y >= VIRTUAL_HEIGHT then
            if self.powerup.type == 4 then 
                self.keyCountdown = 15
            end
            self.powerup.spawned = false
        end


    end

    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    for i, ball in pairs(self.balls) do
        ball:render()
    end

    if self.powerup.spawned then
        self.powerup:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end