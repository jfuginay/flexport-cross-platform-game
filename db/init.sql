-- FlexPort Game Database Schema

-- Players table
CREATE TABLE IF NOT EXISTS players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    company_name VARCHAR(255) NOT NULL,
    money DECIMAL(15, 2) DEFAULT 30000000,
    reputation INTEGER DEFAULT 50 CHECK (reputation >= 0 AND reputation <= 100),
    is_ai BOOLEAN DEFAULT FALSE,
    ai_personality VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ships table
CREATE TABLE IF NOT EXISTS ships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID REFERENCES players(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    capacity INTEGER NOT NULL,
    speed DECIMAL(5, 2) NOT NULL,
    health INTEGER DEFAULT 100 CHECK (health >= 0 AND health <= 100),
    status VARCHAR(50) DEFAULT 'IDLE',
    position_lat DECIMAL(10, 6),
    position_lng DECIMAL(10, 6),
    destination_port_id UUID,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ports table
CREATE TABLE IF NOT EXISTS ports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    country VARCHAR(255) NOT NULL,
    latitude DECIMAL(10, 6) NOT NULL,
    longitude DECIMAL(10, 6) NOT NULL,
    demand_level VARCHAR(50) DEFAULT 'MEDIUM',
    owner_id UUID REFERENCES players(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Contracts table
CREATE TABLE IF NOT EXISTS contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    origin_port_id UUID REFERENCES ports(id),
    destination_port_id UUID REFERENCES ports(id),
    cargo_type VARCHAR(100) NOT NULL,
    cargo_amount INTEGER NOT NULL,
    value DECIMAL(12, 2) NOT NULL,
    deadline TIMESTAMP NOT NULL,
    status VARCHAR(50) DEFAULT 'AVAILABLE',
    assigned_ship_id UUID REFERENCES ships(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Transactions table
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_id UUID REFERENCES players(id),
    type VARCHAR(50) NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Routes history table
CREATE TABLE IF NOT EXISTS route_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ship_id UUID REFERENCES ships(id),
    origin_port_id UUID REFERENCES ports(id),
    destination_port_id UUID REFERENCES ports(id),
    departure_time TIMESTAMP,
    arrival_time TIMESTAMP,
    revenue DECIMAL(12, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Market trends table
CREATE TABLE IF NOT EXISTS market_trends (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    route VARCHAR(255) NOT NULL,
    demand_trend VARCHAR(20) NOT NULL,
    price_change DECIMAL(5, 2),
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_ships_player_id ON ships(player_id);
CREATE INDEX idx_ships_status ON ships(status);
CREATE INDEX idx_contracts_status ON contracts(status);
CREATE INDEX idx_transactions_player_id ON transactions(player_id);
CREATE INDEX idx_route_history_ship_id ON route_history(ship_id);

-- Insert initial ports
INSERT INTO ports (name, country, latitude, longitude, demand_level) VALUES
('Shanghai', 'China', 31.2304, 121.4737, 'HIGH'),
('Singapore', 'Singapore', 1.3521, 103.8198, 'HIGH'),
('Rotterdam', 'Netherlands', 51.9244, 4.4777, 'HIGH'),
('Dubai', 'UAE', 25.2048, 55.2708, 'MEDIUM'),
('Los Angeles', 'USA', 33.7405, -118.2723, 'HIGH'),
('Hamburg', 'Germany', 53.5511, 9.9937, 'MEDIUM'),
('Antwerp', 'Belgium', 51.2194, 4.4025, 'MEDIUM'),
('Hong Kong', 'China', 22.3193, 114.1694, 'HIGH'),
('Busan', 'South Korea', 35.1796, 129.0756, 'MEDIUM'),
('Tokyo', 'Japan', 35.6762, 139.6503, 'HIGH');

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_players_updated_at BEFORE UPDATE ON players
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ships_updated_at BEFORE UPDATE ON ships
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ports_updated_at BEFORE UPDATE ON ports
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contracts_updated_at BEFORE UPDATE ON contracts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();