-- Create the Player Details table
CREATE TABLE PlayerDetails (
    P_ID int PRIMARY KEY,
    PName varchar(50) NOT NULL,
    L1_status bit NOT NULL,
    L2_status bit NOT NULL,
    L1_code varchar(50) NOT NULL,
    L2_code varchar(50) NOT NULL
);

ALTER TABLE PlayerDetails ALTER COLUMN L1_status varchar(30);
ALTER TABLE PlayerDetails ALTER COLUMN L2_status varchar(30);
ALTER TABLE PlayerDetails drop myunknowncolumn;

-- Create the Level Details table
CREATE TABLE LevelDetails (
    P_ID int FOREIGN KEY REFERENCES PlayerDetails(P_ID),
    Dev_ID nvarchar NOT NULL,
    start_time datetime NOT NULL,
    stages_crossed int NOT NULL,
    leval_ int NOT NULL,
    difficulty varchar(10) NOT NULL,
    kill_count int NOT NULL,
    headshots_count int NOT NULL,
    score int NOT NULL,
    lives_earned int NOT NULL
);

ALTER TABLE LevelDetails ALTER COLUMN start_time DATETIME;
ALTER TABLE LevelDetails ALTER COLUMN Dev_ID VARCHAR(10);
ALTER TABLE LevelDetails ALTER COLUMN difficulty VARCHAR(15);
--ALTER TABLE LevelDetails ADD PRIMARY KEY(P_ID,Dev_id,start_datetime);

-- Insert Data into PlayerDetails Tables
BULK INSERT PlayerDetails
	from 'C:\AKP\Job\05 Mentorness\02 Project1-Game Analysis\player_details2.csv'
	with
	(
	Firstrow = 2,
	fieldterminator = ',',
	rowterminator = '\n'
	);

SELECT * from PlayerDetails

-- Insert Data into LevelDetails Tables
BULK INSERT LevelDetails
	from 'C:\AKP\Job\05 Mentorness\02 Project1-Game Analysis\level_details22.csv'
	with
	(
	Firstrow = 2,
	fieldterminator = ',',
	rowterminator = '\n'
	);

select * from LevelDetails

-- Q1) Extract P_ID,Dev_ID,PName and Difficulty_level of all players at level 0

SELECT pd.P_ID, pd.PName, ld.Dev_ID, LD.leval_, ld.difficulty AS Difficulty_level
FROM PlayerDetails pd 
JOIN LevelDetails ld
ON pd.P_ID = ld.P_ID
WHERE ld.leval_ = 0;

-- Q2) Find Level1_code wise Avg_Kill_Count where lives_earned is 2 and atleast 3 stages are crossed
SELECT pd.L1_code AS Level1_Code, AVG(ld.kill_count) AS avg_kill_count
FROM LevelDetails ld 
JOIN PlayerDetails pd
ON ld.P_ID = pd.P_ID
WHERE ld.lives_earned = 2 AND ld.stages_crossed>=3 
GROUP BY pd.L1_code;

-- Q3) Find the total number of stages crossed at each diffuculty level 
--     where for Level2 with players use zm_series devices. 
--     Arrange the result in decsreasing order of total number of stages crossed.

SELECT SUM(ld.stages_crossed) AS total_stages_crossed, 
		ld.difficulty AS difficulty_level
FROM LevelDetails ld
JOIN PlayerDetails pd 
ON ld.P_ID = pd.P_ID
WHERE ld.leval_ = 2 AND ld.Dev_ID LIKE 'zm_%'
GROUP BY difficulty
ORDER BY total_stages_crossed DESC;

-- Q4) Extract P_ID and the total number of unique dates for those players 
--     who have played games on multiple days.
SELECT P_ID, COUNT(DISTINCT(start_time)) AS days_played
FROM LevelDetails
GROUP BY P_ID
HAVING COUNT(DISTINCT (start_time)) > 1
ORDER BY days_played DESC;

-- Q5) Find P_ID and level wise sum of kill_counts where kill_count
--     is greater than avg kill count for the Medium difficulty.

SELECT ld.P_ID, ld.leval_, SUM(ld.kill_count) AS total_kill_count
FROM LevelDetails ld
JOIN (
    SELECT leval_, AVG(kill_count) AS avg_kill_count
    FROM LevelDetails
    WHERE difficulty = 'medium'
    GROUP BY leval_
) AS avg_kills ON ld.leval_ = avg_kills.leval_
WHERE ld.difficulty = 'medium' AND ld.kill_count > avg_kills.avg_kill_count
GROUP BY ld.P_ID, ld.leval_;

-- Q6)  Find Level and its corresponding Level code wise sum of lives earned 
--		excluding level 0. Arrange in asecending order of level.

SELECT ld.leval_, pd.L1_code AS Level_Code, SUM(ld.lives_earned) AS Total_Lives_Earned
FROM LevelDetails ld
JOIN PlayerDetails pd 
ON ld.P_ID = pd.P_ID
WHERE ld.leval_ > 0
GROUP BY ld.leval_, pd.L1_code
ORDER BY ld.leval_ ASC;

-- Q7) Find Top 3 score based on each dev_id and Rank them in increasing order
--     using Row_Number. Display difficulty as well.

WITH RankedScores AS (
    SELECT
        ld.Dev_ID,
        ld.score,
        ld.difficulty,
        ROW_NUMBER() OVER (PARTITION BY ld.Dev_ID ORDER BY ld.score DESC) AS Rank
    FROM
        LevelDetails ld
)
SELECT
    Dev_ID,
    score,
    difficulty
FROM
    RankedScores
WHERE
    Rank <= 3
ORDER BY
    Dev_ID ASC,
    Rank ASC;

-- Q8) Find first_login datetime for each device id

SELECT Dev_ID, MIN(start_time) AS first_login_datetime
FROM LevelDetails
GROUP BY Dev_ID;

-- Q9) Find Top 5 score based on each difficulty level and Rank them in 
--	   increasing order using Rank. Display dev_id as well.

WITH RankedScores AS (
    SELECT
        Dev_ID,
        score,
        difficulty,
        RANK() OVER (PARTITION BY difficulty ORDER BY score DESC) AS Rank
    FROM
        LevelDetails
)
SELECT
    Dev_ID,
    score,
    difficulty,
    Rank
FROM
    RankedScores
WHERE
    Rank <= 5
ORDER BY difficulty ASC,
    Rank ASC;

-- Q10) Find the device ID that is first logged in(based on start_datetime) 
--		for each player(p_id). Output should contain player id, device id and 
--		first login datetime.

SELECT ld.P_ID, ld.Dev_ID, ld.start_time AS first_login_datetime
FROM LevelDetails ld
INNER JOIN (
    SELECT P_ID, MIN(start_time) AS min_start_time
    FROM LevelDetails
    GROUP BY P_ID
) AS first_login ON ld.P_ID = first_login.P_ID AND ld.start_time = first_login.min_start_time;

-- Q11) For each player and date, how many kill_count played so far by the player. That is, the total number of games played -- by the player until that date.
--		a) window function

-- Assuming the appropriate date functions are available, such as DATEPART in SQL Server
SELECT
    P_ID,
    CAST(start_time AS DATE) AS game_date, -- used CAST function to convert start_time as DATE
    SUM(kill_count) OVER (PARTITION BY P_ID ORDER BY CAST(start_time AS DATE)) AS total_kill_count
FROM
    LevelDetails;


-- b) without window function

SELECT
    ld.P_ID,
    CAST(ld.start_time AS DATE) AS game_date, 
    (SELECT SUM(ld2.kill_count)
     FROM LevelDetails ld2
     WHERE ld2.P_ID = ld.P_ID AND CAST(ld2.start_time AS DATE) <= CAST(ld.start_time AS DATE)
    ) AS total_kill_count
FROM
    LevelDetails ld;

-- Q12) Find the cumulative sum of stages crossed over a start_datetime 

SELECT start_time, stages_crossed, SUM(stages_crossed) 
OVER (ORDER BY start_time) AS cumulative_stages_crossed
FROM LevelDetails;

-- Q13) Find the cumulative sum of an stages crossed over a start_datetime 
-- for each player id but exclude the most recent start_datetime

SELECT ld.P_ID, ld.start_time, ld.stages_crossed,
    (SELECT SUM(ld2.stages_crossed) 
     FROM LevelDetails ld2 
     WHERE ld2.P_ID = ld.P_ID AND ld2.start_time <= ld.start_time
        AND ld2.start_time < (SELECT MAX(ld3.start_time) FROM LevelDetails ld3 WHERE ld3.P_ID = ld.P_ID)
    ) AS cumulative_stages_crossed
FROM
    LevelDetails ld;

-- Q14) Extract top 3 highest sum of score for each device id and the corresponding player_id

WITH RankedScores AS (
    SELECT
        ld.P_ID,
        ld.Dev_ID,
        SUM(ld.score) AS total_score,
        RANK() OVER (PARTITION BY ld.Dev_ID ORDER BY SUM(ld.score) DESC) AS score_rank
    FROM
        LevelDetails ld
    GROUP BY
        ld.Dev_ID, ld.P_ID
)
SELECT
    P_ID,
    Dev_ID,
    total_score
FROM
    RankedScores
WHERE
    score_rank <= 3;

-- Q15) Find players who scored more than 50% of the avg score scored by sum of 
-- scores for each player_id

WITH PlayerAvgScore AS (
    SELECT ld.P_ID, AVG(ld.score) AS avg_score
    FROM LevelDetails ld
    GROUP BY ld.P_ID
)
SELECT ld.P_ID, SUM(ld.score) AS total_score
FROM LevelDetails ld
JOIN
    PlayerAvgScore pas ON ld.P_ID = pas.P_ID
GROUP BY
    ld.P_ID
HAVING
    SUM(ld.score) > 0.5 * (SELECT avg_score FROM PlayerAvgScore WHERE P_ID = ld.P_ID);

-- Q16) Create a stored procedure to find top n headshots_count based on each dev_id and Rank them in increasing order
-- using Row_Number. Display difficulty as well.

CREATE PROCEDURE GetTopNHeadshotsByDevId
    @n INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH RankedHeadshots AS (
        SELECT Dev_ID, difficulty, headshots_count,
            ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY headshots_count ASC) AS rank
        FROM LevelDetails
    )
    SELECT Dev_ID,difficulty,headshots_count
    FROM RankedHeadshots
    WHERE rank <= @n;
END;

EXEC GetTopNHeadshotsByDevId @n = 5;

-- Q17) Create a function to return sum of Score for a given player_id.

CREATE FUNCTION GetPlayerScoreSum
(
    @player_id INT
)
RETURNS INT
AS
BEGIN
    DECLARE @sum_score INT;

    SELECT @sum_score = SUM(score)
    FROM LevelDetails
    WHERE P_ID = @player_id;

    RETURN ISNULL(@sum_score, 0);
END;

SELECT dbo.GetPlayerScoreSum(211) AS PlayerScoreSum;
