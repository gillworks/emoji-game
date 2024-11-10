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
from typing import Optional, Dict

# Load environment variables from .env.local
load_dotenv('.env.local')

class TerrainGenerator:
    def __init__(self, width, height, supabase_url, supabase_key):
        self.width = width
        self.height = height
        self.supabase = create_client(supabase_url, supabase_key)
        
        # Load terrain types from database
        result = self.supabase.table('terrain_types').select('*').execute()
        self.terrain_types = {
            terrain['id'].strip(): terrain['emoji'] 
            for terrain in result.data
        }
        
        # Portal config
        self.portal_configs = {
            'HOUSE': {
                'chance': 1.00,  # 100% chance for houses to be portals
                'destinations': [
                    {'name': 'house_interior', 'width': 10, 'height': 10}
                ]
            }
        }

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

    def create_new_server(self, server_name, max_players=100, width=None, height=None):
        """Create a new server in the database"""
        server_data = {
            'id': str(uuid.uuid4()),
            'name': server_name,
            'status': 'active',
            'created_at': datetime.utcnow().isoformat(),
            'last_active': datetime.utcnow().isoformat(),
            'max_players': max_players,
            'map_width': width if width is not None else self.width,
            'map_height': height if height is not None else self.height
        }
        
        # Insert server record
        result = self.supabase.table('servers').insert(server_data).execute()
        return result.data[0]

    def create_interior_server(self, name: str, width: int, height: int) -> Optional[Dict]:
        try:
            server = self.create_new_server(
                server_name=f"{name}-{uuid.uuid4().hex[:8]}",
                max_players=10,
                width=width,
                height=height
            )
            
            # Create a map of terrain types we'll use
            interior_terrains = {
                'floor': 'FLOOR',
                'door': 'DOOR',
                'storage': 'STORAGE_CHEST'
            }
            
            # Generate interior map (all floor with door at bottom)
            terrain_map = np.full((height, width), interior_terrains['floor'], dtype='U15')
            
            # Add door at bottom center
            door_x = width // 2
            door_y = height - 1
            terrain_map[door_y][door_x] = interior_terrains['door']
            
            # Initialize map_data list
            map_data = []
            
            # Add storage chests along walls (10% chance per wall position)
            for x in [0, width-1]:  # Left and right walls
                for y in range(height):
                    if y != door_y and random.random() < 0.1:  # Avoid placing on door row
                        terrain_map[y][x] = interior_terrains['storage']
                        metadata = {
                            'structure_id': 'STORAGE_CHEST',
                            'built_at': datetime.utcnow().isoformat()
                            # No owner_id means it's a public chest
                        }
                        map_data.append({
                            'server_id': server['id'],
                            'x': x,
                            'y': y,
                            'terrain_type': interior_terrains['storage'],
                            'original_terrain_type': interior_terrains['storage'],
                            'metadata': metadata
                        })
            
            for y in [0]:  # Top wall only (bottom has door)
                for x in range(width):
                    if random.random() < 0.1:
                        terrain_map[y][x] = interior_terrains['storage']
                        metadata = {
                            'structure_id': 'STORAGE_CHEST',
                            'built_at': datetime.utcnow().isoformat()
                            # No owner_id means it's a public chest
                        }
                        map_data.append({
                            'server_id': server['id'],
                            'x': x,
                            'y': y,
                            'terrain_type': interior_terrains['storage'],
                            'original_terrain_type': interior_terrains['storage'],
                            'metadata': metadata
                        })
            
            # Add remaining tiles to map_data
            for y in range(height):
                for x in range(width):
                    # Skip if we already added this position as a storage chest
                    if not any(tile['x'] == x and tile['y'] == y for tile in map_data):
                        terrain = str(terrain_map[y][x])
                        metadata = {}
                        
                        # Verify terrain type is valid
                        if terrain not in self.terrain_types:
                            raise ValueError(f"Invalid terrain type: {terrain}")
                        
                        map_data.append({
                            'server_id': server['id'],
                            'x': x,
                            'y': y,
                            'terrain_type': terrain,
                            'original_terrain_type': terrain,
                            'metadata': metadata
                        })
            
            # Insert map data
            self.supabase.table('map_data').insert(map_data).execute()
            
            return {
                'server': server,
                'door_position': {'x': door_x, 'y': door_y}
            }
            
        except Exception as e:
            print(f"Error creating interior server: {e}")
            if 'server' in locals():
                try:
                    self.supabase.table('servers').delete().eq('id', server['id']).execute()
                except Exception as cleanup_error:
                    print(f"Error cleaning up server: {cleanup_error}")
            return None

    def generate_and_save_map(self, server_name, max_players=100):
        """Generate a new map and save it to the database"""
        try:
            # Create new server
            server = self.create_new_server(server_name, max_players)
            server_id = server['id']
            
            # Track created interior servers and their entry points
            interior_servers = {}
            house_positions = []
            
            # Generate terrain map
            terrain_map = self.generate_map()
            
            # Add some houses on plains (5% chance)
            for y in range(self.height):
                for x in range(self.width):
                    if terrain_map[y][x] == 'PLAIN' and random.random() < 0.05:
                        terrain_map[y][x] = 'HOUSE'
                        house_positions.append({'x': x, 'y': y})
            
            # Prepare map data for insertion
            map_data = []
            for y in range(self.height):
                for x in range(self.width):
                    terrain = terrain_map[y][x]
                    metadata = {}
                    
                    # Configure house portals
                    if terrain == 'HOUSE':
                        destination = self.portal_configs['HOUSE']['destinations'][0]
                        interior_result = self.create_interior_server(
                            name=destination['name'],
                            width=destination['width'],
                            height=destination['height']
                        )
                        
                        if interior_result:
                            interior_servers[f"{x}_{y}"] = interior_result
                            metadata['portal_config'] = {
                                'destination_server': interior_result['server']['id'],
                                'destination_x': destination['width'] // 2,
                                'destination_y': destination['height'] - 1
                            }
                    
                    map_data.append({
                        'server_id': server_id,
                        'x': x,
                        'y': y,
                        'terrain_type': terrain,
                        'original_terrain_type': terrain,
                        'metadata': metadata
                    })
            
            # Insert map data
            self.supabase.table('map_data').insert(map_data).execute()
            
            # Configure return portals in interior servers
            for pos_key, interior_data in interior_servers.items():
                x, y = map(int, pos_key.split('_'))
                
                print(f"Configuring return portal for house at {x},{y}")
                print(f"Door position: {interior_data['door_position']}")
                print(f"Interior server: {interior_data['server']['id']}")
                
                try:
                    result = self.supabase.rpc('configure_portal', {
                        'p_server_id': interior_data['server']['id'],
                        'p_x': interior_data['door_position']['x'],
                        'p_y': interior_data['door_position']['y'],
                        'p_destination_server': server_id,
                        'p_destination_x': x,
                        'p_destination_y': y
                    }).execute()

                    if result.data.get('success'):
                        print(f"Successfully configured return portal: {result.data['message']}")
                    else:
                        print(f"Failed to configure return portal: {result.data}")
                        
                except Exception as e:
                    print(f"Error configuring return portal: {str(e)}")
            
            return {
                'server_id': server_id,
                'name': server_name,
                'map_size': f"{self.width}x{self.height}",
                'tiles_created': len(map_data),
                'houses_created': len(house_positions),
                'interior_servers': len(interior_servers)
            }
            
        except Exception as e:
            # Clean up on error
            if 'server_id' in locals():
                self.supabase.table('servers').delete().eq('id', server_id).execute()
                # Also clean up any created interior servers
                for interior in interior_servers.values():
                    self.supabase.table('servers').delete().eq('id', interior['server']['id']).execute()
            raise Exception(f"Error generating map: {str(e)}")

# Modified usage example
def create_new_game_world(width=120, height=120):
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
    result = generator.generate_and_save_map(
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

    def main():
        try:
            result = create_new_game_world(width=args.width, height=args.height)
            print("Successfully created new world:", result)
        except Exception as e:
            print(f"Error creating world: {e}")
    
    # Run the function
    main()
