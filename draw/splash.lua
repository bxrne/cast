-- Surface splash pool. Fixed cap, no alloc after new.
-- Rings spread on the film. Drops fly on a breach.
local splash = {}
splash.__index = splash

local CAP = 160

function splash.new(cap)
  local self = setmetatable({ n = 0 }, splash)
  self.cap = cap or CAP
  self.kind = {}
  self.x = {}
  self.y = {}
  self.vx = {}
  self.vy = {}
  self.age = {}
  self.life = {}
  self.r0 = {}
  self.r1 = {}
  for i = 1, self.cap do
    self.kind[i] = 0
    self.x[i] = 0
    self.y[i] = 0
    self.vx[i] = 0
    self.vy[i] = 0
    self.age[i] = 0
    self.life[i] = 1
    self.r0[i] = 2
    self.r1[i] = 6
  end
  return self
end

function splash:reset()
  self.n = 0
end

-- Add one item. Swap reuse keeps the live set packed.
local function push(self, kind, x, y, vx, vy, life, r0, r1)
  local i
  if self.n < self.cap then
    self.n = self.n + 1
    i = self.n
  else
    i = 1 + ((math.floor(x + y) % self.cap + self.cap) % self.cap)
  end
  self.kind[i] = kind
  self.x[i] = x
  self.y[i] = y
  self.vx[i] = vx or 0
  self.vy[i] = vy or 0
  self.age[i] = 0
  self.life[i] = math.max(0.05, life or 0.6)
  self.r0[i] = r0 or 2
  self.r1[i] = r1 or 8
end

-- Expanding ring at world pos.
function splash:ring(x, y, r1, life)
  push(self, 1, x, y, 0, 0, life or 0.8, 2, r1 or 10)
end

-- Faint dimple. One soft touch of the film, not a wake.
function splash:dimple(x, y, r)
  push(self, 3, x, y, 0, 0, 1.1, 1, r or 4)
end

-- Flying drop with velocity.
function splash:drop(x, y, vx, vy, life, r)
  push(self, 2, x, y, vx, vy, life or 0.45, r or 1.6, r or 1.6)
end

function splash:update(dt)
  local n = self.n
  local i = 1
  while i <= n do
    self.age[i] = self.age[i] + dt
    if self.age[i] >= self.life[i] then
      local last = n
      self.kind[i] = self.kind[last]
      self.x[i] = self.x[last]
      self.y[i] = self.y[last]
      self.vx[i] = self.vx[last]
      self.vy[i] = self.vy[last]
      self.age[i] = self.age[last]
      self.life[i] = self.life[last]
      self.r0[i] = self.r0[last]
      self.r1[i] = self.r1[last]
      n = n - 1
    else
      if self.kind[i] == 2 then
        self.x[i] = self.x[i] + self.vx[i] * dt
        self.y[i] = self.y[i] + self.vy[i] * dt
        self.vy[i] = self.vy[i] + 260 * dt
      end
      i = i + 1
    end
  end
  self.n = n
end

function splash:draw()
  for i = 1, self.n do
    local u = self.age[i] / self.life[i]
    if self.kind[i] == 1 then
      local r = self.r0[i] + (self.r1[i] - self.r0[i]) * u
      love.graphics.setColor(0.88, 0.92, 0.86, 0.42 * (1 - u))
      love.graphics.setLineWidth(1)
      love.graphics.ellipse("line", self.x[i], self.y[i], r, r * 0.55)
    elseif self.kind[i] == 3 then
      local r = self.r0[i] + (self.r1[i] - self.r0[i]) * u
      love.graphics.setColor(0.88, 0.92, 0.86, 0.16 * (1 - u))
      love.graphics.setLineWidth(1)
      love.graphics.ellipse("line", self.x[i], self.y[i], r, r * 0.55)
    else
      love.graphics.setColor(0.92, 0.95, 0.90, 0.75 * (1 - u))
      love.graphics.points(self.x[i], self.y[i])
    end
  end
end

return splash
