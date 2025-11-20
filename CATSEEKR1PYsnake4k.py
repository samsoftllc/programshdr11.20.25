import pygame
import random
import math
import array
import sys

# --- CONSTANTS & CONFIG ---
# PS1 Native Resolution (Low Res for the aesthetic)
NATIVE_WIDTH = 320
NATIVE_HEIGHT = 240
# Window Resolution (Upscaled)
WINDOW_WIDTH = 800
WINDOW_HEIGHT = 600

# Grid
GRID_SIZE = 16
GRID_W = NATIVE_WIDTH // GRID_SIZE
GRID_H = NATIVE_HEIGHT // GRID_SIZE

# Colors (Gritty PS1 Palette)
BLACK = (10, 10, 15)
DARK_GRAY = (40, 40, 50)
PS1_BG = (20, 0, 30)
NEON_GREEN = (0, 255, 100)
BLOOD_RED = (200, 20, 20)  # Defined here as BLOOD_RED
WHITE = (220, 220, 220)
GOLD = (255, 215, 0)

# --- PROCEDURAL AUDIO ENGINE ---
class SoundGen:
    def __init__(self):
        # Standard CD quality audio
        self.sample_rate = 44100
        pygame.mixer.init(frequency=self.sample_rate, size=-16, channels=1, buffer=512)
    
    def make_sound(self, wave_type, freq_start, freq_end, duration, volume=0.5):
        n_samples = int(self.sample_rate * duration)
        buf = array.array('h')
        
        for i in range(n_samples):
            t = float(i) / self.sample_rate
            # Frequency slide (Linear interpolation)
            f = freq_start + (freq_end - freq_start) * (i / n_samples)
            
            val = 0
            if wave_type == "sine":
                val = math.sin(2 * math.pi * f * t)
            elif wave_type == "square":
                val = 1.0 if math.sin(2 * math.pi * f * t) > 0 else -1.0
            elif wave_type == "saw":
                val = 2.0 * (f * t - math.floor(0.5 + f * t))
            elif wave_type == "noise":
                val = random.uniform(-1, 1)
            
            # Apply simple envelope (Attack/Decay)
            envelope = 1.0
            if i < n_samples * 0.1: # Attack
                envelope = i / (n_samples * 0.1)
            elif i > n_samples * 0.8: # Decay
                envelope = (n_samples - i) / (n_samples * 0.2)
            
            buf.append(int(val * volume * envelope * 32767))
            
        return pygame.mixer.Sound(buffer=buf)

# --- 3D RENDERING HELPERS ---
def draw_voxel(surface, x, y, color, height_mod=0):
    """ Draws a pseudo-3D cube/voxel """
    iso_x = x 
    iso_y = y
    depth = 6 + height_mod
    
    # Top Face
    pygame.draw.rect(surface, color, (iso_x, iso_y, GRID_SIZE, GRID_SIZE))
    
    # Side Face (Darker for shading)
    side_color = (max(0, color[0]-50), max(0, color[1]-50), max(0, color[2]-50))
    pygame.draw.rect(surface, side_color, (iso_x, iso_y + GRID_SIZE, GRID_SIZE, depth))
    
    # Highlight (Wireframe-ish)
    pygame.draw.rect(surface, (color[0]//2, color[1]//2, color[2]//2), (iso_x, iso_y, GRID_SIZE, GRID_SIZE), 1)

def draw_scanlines(surface):
    """ Applies CRT effect """
    for y in range(0, WINDOW_HEIGHT, 3):
        # Semi-transparent black lines
        s = pygame.Surface((WINDOW_WIDTH, 1), pygame.SRCALPHA)
        s.fill((0, 0, 0, 100))
        surface.blit(s, (0, y))

# --- GAME CLASSES ---
class Particle:
    def __init__(self, x, y, color):
        self.x = x
        self.y = y
        self.vx = random.uniform(-2, 2)
        self.vy = random.uniform(-4, -1)
        self.life = 1.0
        self.color = color

    def update(self):
        self.x += self.vx
        self.y += self.vy
        self.vy += 0.2 # Gravity
        self.life -= 0.05

    def draw(self, surface):
        if self.life > 0:
            s = int(4 * self.life)
            pygame.draw.rect(surface, self.color, (self.x, self.y, s, s))

class Snake:
    def __init__(self):
        self.reset()

    def reset(self):
        self.x = GRID_W // 2
        self.y = GRID_H // 2
        self.direction = "right"
        self.next_direction = "right"
        self.body = [(self.x, self.y), (self.x-1, self.y), (self.x-2, self.y)]
        self.score = 0
        self.grow_pending = 0

    def update(self):
        self.direction = self.next_direction
        
        if self.direction == "up": self.y -= 1
        elif self.direction == "down": self.y += 1
        elif self.direction == "left": self.x -= 1
        elif self.direction == "right": self.x += 1

        # Wall Collision
        if self.x < 0 or self.x >= GRID_W or self.y < 0 or self.y >= GRID_H:
            return False # Dead

        # Self Collision
        if (self.x, self.y) in self.body:
            return False # Dead

        self.body.insert(0, (self.x, self.y))
        
        if self.grow_pending > 0:
            self.grow_pending -= 1
        else:
            self.body.pop()
            
        return True

    def draw(self, surface):
        for i, segment in enumerate(self.body):
            # Calculate color gradient for the snake
            g_val = max(100, 255 - (i * 5))
            color = (0, g_val, 50)
            if i == 0: color = NEON_GREEN # Head is bright
            
            draw_x = segment[0] * GRID_SIZE
            draw_y = segment[1] * GRID_SIZE
            draw_voxel(surface, draw_x, draw_y, color)

class Food:
    def __init__(self):
        self.respawn([])

    def respawn(self, snake_body):
        while True:
            self.x = random.randint(0, GRID_W - 1)
            self.y = random.randint(0, GRID_H - 1)
            if (self.x, self.y) not in snake_body:
                break
        self.pulse = 0

    def draw(self, surface):
        self.pulse += 0.2
        size_mod = math.sin(self.pulse) * 2
        
        draw_x = self.x * GRID_SIZE
        draw_y = self.y * GRID_SIZE
        
        # Flashing Red/Gold
        color = BLOOD_RED if int(self.pulse * 5) % 2 == 0 else GOLD
        draw_voxel(surface, draw_x, draw_y - size_mod, color)

# --- MAIN ENGINE ---
def main():
    pygame.init()
    pygame.font.init() 
    
    screen = pygame.display.set_mode((WINDOW_WIDTH, WINDOW_HEIGHT))
    pygame.display.set_caption("SNAKE // PSX EDITION")
    
    # Render Surface (Low Res)
    native_surf = pygame.Surface((NATIVE_WIDTH, NATIVE_HEIGHT))
    
    # Safe Font Loading
    try:
        title_font = pygame.font.SysFont("couriernew", 40, bold=True)
        ui_font = pygame.font.SysFont("couriernew", 12, bold=True)
    except:
        title_font = pygame.font.Font(None, 40)
        ui_font = pygame.font.Font(None, 20)

    # Audio
    try:
        audio = SoundGen()
        sfx_boot = audio.make_sound("sine", 100, 800, 2.5, 0.4)
        sfx_move = audio.make_sound("noise", 800, 200, 0.05, 0.1)
        sfx_eat = audio.make_sound("square", 400, 900, 0.1, 0.3)
        sfx_die = audio.make_sound("saw", 200, 50, 0.5, 0.5)
        sfx_select = audio.make_sound("sine", 800, 1200, 0.1, 0.3)
    except Exception as e:
        print(f"Audio init failed (ignoring): {e}")
        # Create dummy sound objects if audio fails so game doesn't crash
        class DummySound:
            def play(self): pass
        sfx_boot = sfx_move = sfx_eat = sfx_die = sfx_select = DummySound()

    snake = Snake()
    food = Food()
    particles = []
    
    # States
    STATE_BOOT = 0
    STATE_MENU = 1
    STATE_GAME = 2
    STATE_OVER = 3
    
    current_state = STATE_BOOT
    
    clock = pygame.time.Clock()
    boot_timer = 0
    flash_timer = 0
    
    running = True
    sfx_boot.play()

    while running:
        # 1. Event Handling
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            
            if event.type == pygame.KEYDOWN:
                if current_state == STATE_BOOT:
                    current_state = STATE_MENU
                    
                elif current_state == STATE_MENU:
                    if event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                        sfx_select.play()
                        snake.reset()
                        food.respawn(snake.body)
                        particles = []
                        current_state = STATE_GAME
                    if event.key == pygame.K_ESCAPE:
                        running = False
                        
                elif current_state == STATE_GAME:
                    if event.key == pygame.K_w and snake.direction != "down": snake.next_direction = "up"
                    elif event.key == pygame.K_s and snake.direction != "up": snake.next_direction = "down"
                    elif event.key == pygame.K_a and snake.direction != "right": snake.next_direction = "left"
                    elif event.key == pygame.K_d and snake.direction != "left": snake.next_direction = "right"
                    
                elif current_state == STATE_OVER:
                    if event.key == pygame.K_r:
                        sfx_select.play()
                        current_state = STATE_MENU
                    if event.key == pygame.K_ESCAPE:
                        running = False

        # 2. Update Logic
        if current_state == STATE_BOOT:
            boot_timer += 1
            if boot_timer > 180: # 3 seconds
                current_state = STATE_MENU
                
        elif current_state == STATE_MENU:
            flash_timer += 1
            
        elif current_state == STATE_GAME:
            # Particles
            for p in particles[:]:
                p.update()
                if p.life <= 0: particles.remove(p)
            
            # Move Snake (Speed Control)
            if pygame.time.get_ticks() % 100 < 20: 
                alive = snake.update()
                if not alive:
                    sfx_die.play()
                    current_state = STATE_OVER
                else:
                    # Check Food
                    if snake.x == food.x and snake.y == food.y:
                        sfx_eat.play()
                        snake.score += 100
                        snake.grow_pending += 1
                        food.respawn(snake.body)
                        # Spawn particles (FIXED HERE: used BLOOD_RED)
                        for _ in range(10):
                            particles.append(Particle(food.x*GRID_SIZE, food.y*GRID_SIZE, BLOOD_RED))

        # 3. Draw to Native Surface (Low Res)
        native_surf.fill(BLACK)
        
        if current_state == STATE_BOOT:
            native_surf.fill(WHITE)
            center = (NATIVE_WIDTH//2, NATIVE_HEIGHT//2)
            pygame.draw.polygon(native_surf, (255, 165, 0), [
                (center[0], center[1]-40),
                (center[0]+40, center[1]),
                (center[0], center[1]+40),
                (center[0]-40, center[1])
            ])
            t = title_font.render("PyStation", False, BLACK)
            native_surf.blit(t, (center[0]-t.get_width()//2, center[1]+50))
            
        elif current_state == STATE_MENU:
            # Grid Background
            for x in range(0, NATIVE_WIDTH, GRID_SIZE):
                pygame.draw.line(native_surf, DARK_GRAY, (x, 0), (x, NATIVE_HEIGHT))
            for y in range(0, NATIVE_HEIGHT, GRID_SIZE):
                pygame.draw.line(native_surf, DARK_GRAY, (0, y), (NATIVE_WIDTH, y))
                
            t1 = title_font.render("METAL SNAKE", False, NEON_GREEN)
            t1s = title_font.render("METAL SNAKE", False, (0, 50, 0)) # Shadow
            native_surf.blit(t1s, (42, 62))
            native_surf.blit(t1, (40, 60))
            
            if (flash_timer // 30) % 2 == 0:
                msg = ui_font.render("PRESS START [ENTER]", False, WHITE)
                native_surf.blit(msg, (NATIVE_WIDTH//2 - msg.get_width()//2, 180))
                
        elif current_state == STATE_GAME:
            native_surf.fill(PS1_BG)
            offset = random.randint(0, 1)
            for x in range(0, NATIVE_WIDTH, GRID_SIZE):
                pygame.draw.line(native_surf, (30, 0, 40), (x+offset, 0), (x, NATIVE_HEIGHT))
            for y in range(0, NATIVE_HEIGHT, GRID_SIZE):
                pygame.draw.line(native_surf, (30, 0, 40), (0, y+offset), (NATIVE_WIDTH, y))

            food.draw(native_surf)
            snake.draw(native_surf)
            
            for p in particles:
                p.draw(native_surf)
            
            score_t = ui_font.render(f"SCORE: {snake.score}", False, WHITE)
            native_surf.blit(score_t, (5, 5))
            
        elif current_state == STATE_OVER:
            native_surf.fill((50, 0, 0))
            t = title_font.render("YOU DIED", False, WHITE)
            native_surf.blit(t, (NATIVE_WIDTH//2 - t.get_width()//2, NATIVE_HEIGHT//2 - 40))
            
            s = ui_font.render(f"FINAL SCORE: {snake.score}", False, GOLD)
            native_surf.blit(s, (NATIVE_WIDTH//2 - s.get_width()//2, NATIVE_HEIGHT//2 + 20))
            
            r = ui_font.render("PRESS 'R' TO RESTART", False, WHITE)
            native_surf.blit(r, (NATIVE_WIDTH//2 - r.get_width()//2, NATIVE_HEIGHT//2 + 50))

        # 4. Upscale & Post-Process
        scaled_surf = pygame.transform.scale(native_surf, (WINDOW_WIDTH, WINDOW_HEIGHT))
        screen.blit(scaled_surf, (0, 0))
        draw_scanlines(screen)
        
        pygame.display.flip()
        clock.tick(30) # 30 FPS limit

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()
