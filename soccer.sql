-- Soccer Analytics

-- Country and League Mapping
SELECT l.country_id, l.name as league_name, c.name as country_name FROM League l
JOIN Country c ON c.id = l.country_id;


-- Match Outcomes by Season
SELECT 
    t.team_long_name AS team,
    m.season,
    COUNT(CASE WHEN m.home_team_goal > m.away_team_goal THEN 1 END) AS wins,
    COUNT(CASE WHEN m.home_team_goal < m.away_team_goal THEN 1 END) AS losses,
    COUNT(CASE WHEN m.home_team_goal = m.away_team_goal THEN 1 END) AS draws
FROM matchtable AS m
JOIN team AS t ON m.home_team_api_id = t.team_api_id
GROUP BY t.team_long_name, m.season;


-- Top 10 Matches in Belgium Leagues Ordered by Date
Select
    m.id, 
    c.name AS country_name, 
    l.name AS league_name, 
    m.season, 
    m.stage, 
    m.date, 
    t.team_long_name AS home_team, 
    AT.team_long_name AS away_team,
    m.home_team_goal, 
    m.away_team_goal                                        
FROM Matchtable m
JOIN Country c ON c.id = m.country_id
JOIN League l ON l.id = m.league_id
LEFT JOIN Team t ON t.team_api_id = m.home_team_api_id
LEFT JOIN Team AT ON AT.team_api_id = m.away_team_api_id
WHERE c.name = 'Belgium'
ORDER BY m.date
LIMIT 10;


-- Create a view to list match details with league, country, and teams
CREATE OR REPLACE VIEW view_league_matches AS
SELECT m.match_api_id, c.country_name, l.name AS league_name, m.season, m.date,
       t_home.team_long_name AS home_team, t_away.team_long_name AS away_team,
       m.home_team_goal, m.away_team_goal
FROM Matches m
JOIN Countries c ON c.id = m.country_id
JOIN Leagues l ON l.id = m.league_id
JOIN Teams t_home ON t_home.team_api_id = m.home_team_api_id
JOIN Teams t_away ON t_away.team_api_id = m.away_team_api_id;


--  Top 5 teams with highest home wins in a specific season
WITH HomeWins AS (
    SELECT home_team_api_id, COUNT(*) AS wins
    FROM matchtable
    WHERE home_team_goal > away_team_goal AND season = '2010/2011'
    GROUP BY home_team_api_id
)
SELECT t.team_long_name as team_name, hw.wins as total_wins
FROM HomeWins hw
JOIN Team t ON t.team_api_id = hw.home_team_api_id
ORDER BY hw.wins DESC
LIMIT 5;


--  List players with above average rating for 2016
SELECT p.player_name, pa.overall_rating
FROM Player_Attributes pa
JOIN Players p ON pa.player_api_id = p.player_api_id
WHERE YEAR(pa.date) = 2016
  AND pa.overall_rating > (
      SELECT AVG(overall_rating)
      FROM Player_Attributes
      WHERE YEAR(date) = 2016
  )
ORDER BY pa.overall_rating DESC
LIMIT 10;


-- Get rating progression of a player over time
DELIMITER //
CREATE PROCEDURE GetPlayerRatingProgression(IN input_player_api INT)
BEGIN
    SELECT date, overall_rating, potential
    FROM Player_Attributes
    WHERE player_api_id = input_player_api
    ORDER BY date;
END //
DELIMITER ;


-- Rank players by total goals in 2018/2019 season using window function
WITH PlayerSeasonRatings AS (
    SELECT 
        pl.player_name,
        m.season,
        ROUND(AVG(pa.overall_rating), 2) AS avg_rating
    FROM 
        player_attributes pa
    JOIN players pl ON pa.player_fifa_api_id = pl.player_fifa_api_id
    JOIN matchtable m ON pa.player_api_id IN (
        m.home_player_1, m.home_player_2, m.home_player_3, m.home_player_4, m.home_player_5,
        m.home_player_6, m.home_player_7, m.home_player_8, m.home_player_9, m.home_player_10, m.home_player_11,
        m.away_player_1, m.away_player_2, m.away_player_3, m.away_player_4, m.away_player_5,
        m.away_player_6, m.away_player_7, m.away_player_8, m.away_player_9, m.away_player_10, m.away_player_11
    )
    WHERE m.season = '2009/2010'
      AND pa.date LIKE '2010%'
    GROUP BY pl.player_name, m.season
)

SELECT 
    player_name,
    season,
    avg_rating,
    RANK() OVER (PARTITION BY season ORDER BY avg_rating DESC) AS rank_in_season
FROM 
    PlayerSeasonRatings
ORDER BY 
    rank_in_season
LIMIT 10;


-- Running total of matches played by each team
SELECT 
    t.team_long_name,
    m.date,
    ROW_NUMBER() OVER (PARTITION BY t.team_long_name ORDER BY m.date) AS match_number
FROM matchtable m
JOIN team t ON t.team_api_id = m.home_team_api_id
ORDER BY t.team_long_name, m.date;


-- Rank players by their average rating per season
WITH PlayerRatings AS (
    SELECT 
        pa.player_api_id,
        p.player_name,
        m.season,
        AVG(pa.overall_rating) AS avg_rating
    FROM player_attributes pa
    JOIN players p ON pa.player_api_id = p.player_api_id
    JOIN matchtable m ON pa.player_api_id IN (
        m.home_player_1, m.home_player_2, m.home_player_3, m.home_player_4, m.home_player_5,
        m.home_player_6, m.home_player_7, m.home_player_8, m.home_player_9, m.home_player_10, m.home_player_11,
        m.away_player_1, m.away_player_2, m.away_player_3, m.away_player_4, m.away_player_5,
        m.away_player_6, m.away_player_7, m.away_player_8, m.away_player_9, m.away_player_10, m.away_player_11
    )
    WHERE m.season = '2010/2011' AND pa.date LIKE '2011%'
    GROUP BY pa.player_api_id, p.player_name, m.season
)
SELECT 
    player_name,
    season,
    ROUND(avg_rating, 2) AS avg_rating,
    RANK() OVER (PARTITION BY season ORDER BY avg_rating DESC) AS season_rank
FROM PlayerRatings
ORDER BY season_rank
LIMIT 10;


 -- Stored Procedure to Get Top Players by Year
DELIMITER //
CREATE PROCEDURE GetTopPlayersByYear (
    IN input_year INT
)
BEGIN
    SELECT 
        p.player_name,
        ROUND(AVG(pa.overall_rating), 2) AS avg_rating
    FROM 
        player_attributes pa
    JOIN 
        players p ON pa.player_api_id = p.player_api_id
    WHERE 
        YEAR(pa.date) = input_year
    GROUP BY 
        p.player_name
    HAVING 
        COUNT(*) >= 5  -- optional: exclude players with very few entries
    ORDER BY 
        avg_rating DESC
    LIMIT 10;
END //

DELIMITER ;


-- Cumulative Average Rating Over Time
SELECT 
    p.player_name,
    pa.date,
    ROUND(
        AVG(pa.overall_rating) OVER (
            PARTITION BY p.player_name 
            ORDER BY pa.date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 2
    ) AS cumulative_avg_rating
FROM player_attributes pa
JOIN players p ON pa.player_api_id = p.player_api_id
ORDER BY p.player_name, pa.date;