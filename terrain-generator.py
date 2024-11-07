import numpy as np
from scipy.ndimage import gaussian_filter
import random
from supabase import create_client
import uuid
from datetime import datetime
import asyncio
from dotenv import load_dotenv
import os
import argparse

# Load environment variables from .env.local
load_dotenv('.env.local')

class TerrainGenerator:
    def __init__(self, width, height, supabase_url, supabase_key):
        self.width = width
        self.height = height
        self.terrain_types = {
            'OCEAN': '🌊',
            'MOUNTAIN': '⛰',
            'FOREST': '🌳',
            'PLAIN': '🌱'
        }
        # Initialize Supabase client
        self.supabase = create_client(supabase_url, supabase_key)
        
    def generate_noise_map(self, scale=50.0, octaves=6):
        """Generate a coherent noise map using multiple octaves of noise"""
        noise_map = np.zeros((self.height, self.width))
        
        for octave in range(octaves):
            frequency = 2 ** octave
            amplitude = 0.5 ** octave
            
            # Generate base noise
            base_noise = np.random.rand(
                self.height // frequency + 2, 
                self.width // frequency + 2
            )
            
            # Apply Gaussian smoothing
            smoothed = gaussian_filter(base_noise, sigma=1.0)
            
            # Resize to match our dimensions
            from scipy.ndimage import zoom
            resized = zoom(smoothed, (
                (self.height / smoothed.shape[0]), 
                (self.width / smoothed.shape[1])
            ))
            
            # Add to our noise map
            noise_map += resized * amplitude
            
        # Normalize to 0-1
        noise_map = (noise_map - noise_map.min()) / (noise_map.max() - noise_map.min())
        return noise_map
    
    def apply_cellular_automata(self, terrain_map, iterations=5):
        """Apply cellular automata to smooth terrain transitions"""
        for _ in range(iterations):
            new_map = terrain_map.copy()
            
            for y in range(self.height):
                for x in range(self.width):
                    # Get neighboring cells
                    neighbors = []
                    for dy in [-1, 0, 1]:
                        for dx in [-1, 0, 1]:
                            if dx == 0 and dy == 0:
                                continue
                            ny, nx = (y + dy) % self.height, (x + dx) % self.width
                            neighbors.append(terrain_map[ny][nx])
                    
                    # Apply rules
                    current = terrain_map[y][x]
                    
                    # Water expands near other water
                    if neighbors.count('OCEAN') >= 5:
                        new_map[y][x] = 'OCEAN'
                    
                    # Mountains form ranges
                    elif current == 'MOUNTAIN' and neighbors.count('MOUNTAIN') >= 3:
                        new_map[y][x] = 'MOUNTAIN'
                    
                    # Forests grow in clusters
                    elif current == 'FOREST' and neighbors.count('FOREST') >= 4:
                        new_map[y][x] = 'FOREST'
            
            terrain_map = new_map
        
        return terrain_map
    
    def generate_map(self):
        """Generate a complete terrain map"""
        # Generate base elevation noise
        elevation = self.generate_noise_map(scale=50.0)
        moisture = self.generate_noise_map(scale=30.0)
        
        # Initialize terrain map
        terrain_map = np.empty((self.height, self.width), dtype='U10')
        
        # Convert noise to terrain types
        for y in range(self.height):
            for x in range(self.width):
                e = elevation[y][x]
                m = moisture[y][x]
                
                # Ocean (low elevation)
                if e < 0.3:
                    terrain_map[y][x] = 'OCEAN'
                
                # Mountains (high elevation)
                elif e > 0.7:
                    terrain_map[y][x] = 'MOUNTAIN'
                
                # Forest (medium-high elevation, high moisture)
                elif e > 0.4 and m > 0.6:
                    terrain_map[y][x] = 'FOREST'
                
                # Plains (everything else)
                else:
                    terrain_map[y][x] = 'PLAIN'
        
        # Apply cellular automata to create more natural patterns
        terrain_map = self.apply_cellular_automata(terrain_map)
        
        return terrain_map

    async def create_new_server(self, server_name, max_players=100):
        """Create a new server in the database"""
        server_data = {
            'id': str(uuid.uuid4()),
            'name': server_name,
            'status': 'active',
            'created_at': datetime.utcnow().isoformat(),
            'last_active': datetime.utcnow().isoformat(),
            'max_players': max_players
        }
        
        # Insert server record
        result = self.supabase.table('servers').insert(server_data).execute()
        return result.data[0]

    async def generate_and_save_map(self, server_name, max_players=100):
        """Generate a new map and save it to the database"""
        try:
            # Create new server
            server = await self.create_new_server(server_name, max_players)
            server_id = server['id']
            
            # Generate terrain map
            terrain_map = self.generate_map()
            
            # Prepare map data for insertion
            map_data = []
            for y in range(self.height):
                for x in range(self.width):
                    terrain = terrain_map[y][x]
                    map_data.append({
                        'server_id': server_id,
                        'x': x,
                        'y': y,
                        'terrain_type': terrain,
                        'original_terrain_type': terrain
                    })
            
            # Insert map data in chunks to avoid request size limits
            chunk_size = 1000
            for i in range(0, len(map_data), chunk_size):
                chunk = map_data[i:i + chunk_size]
                self.supabase.table('map_data').insert(chunk).execute()
            
            return {
                'server_id': server_id,
                'name': server_name,
                'map_size': f"{self.width}x{self.height}",
                'tiles_created': len(map_data)
            }
            
        except Exception as e:
            # If there's an error, attempt to clean up the server if it was created
            if 'server_id' in locals():
                self.supabase.table('servers').delete().eq('id', server_id).execute()
            raise Exception(f"Error generating map: {str(e)}")

# Modified usage example
async def create_new_game_world(width=120, height=120):
    # Get Supabase credentials from environment variables
    supabase_url = os.getenv('NEXT_PUBLIC_SUPABASE_URL')
    supabase_key = os.getenv('NEXT_PUBLIC_SUPABASE_ANON_KEY')
    
    if not supabase_url or not supabase_key:
        raise Exception("Supabase credentials not found in .env.local")
    
    # Initialize generator with environment variables
    generator = TerrainGenerator(
        width=width,
        height=height,
        supabase_url=supabase_url,
        supabase_key=supabase_key
    )
    
    # Generate and save a new map
    result = await generator.generate_and_save_map(
        server_name=f"World-{uuid.uuid4().hex[:8]}",
        max_players=100
    )
    
    return result

# Add this at the bottom of the file to actually run the code
if __name__ == "__main__":
    # Add command line argument parsing
    parser = argparse.ArgumentParser(description='Generate a terrain map')
    parser.add_argument('--width', type=int, default=120, help='Width of the map (default: 120)')
    parser.add_argument('--height', type=int, default=120, help='Height of the map (default: 120)')
    args = parser.parse_args()

    async def main():
        try:
            result = await create_new_game_world(width=args.width, height=args.height)
            print("Successfully created new world:", result)
        except Exception as e:
            print(f"Error creating world: {e}")
    
    # Run the async function
    asyncio.run(main())
