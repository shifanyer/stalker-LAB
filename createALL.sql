CREATE TABLE grouping
(
    groupID           serial  NOT NULL PRIMARY KEY,
    group_name        text    NOT NULL CHECK (
            (group_name like 'Military') OR
            (group_name like 'Bandits') OR
            (group_name = 'Duty') OR
            (group_name = 'Freedom') OR
            (group_name = 'Loners') OR
            (group_name = 'Mercenaries') OR
            (group_name = 'Ecologists') OR
            (group_name = 'Monolith') OR
            (group_name = 'Clear Sky')
        ),
    number_of_members integer NOT NULL CHECK ((number_of_members >= 1) AND (number_of_members <= 1000))
);

CREATE TABLE weapon_type
(
    weaponID    serial      NOT NULL PRIMARY KEY,
    weapon_name Text UNIQUE NOT NULL,
    price       Integer     NOT NULL CHECK ((price >= 0) AND (price <= 20000)),
    damage      Integer     NOT NULL CHECK ((damage >= 5) AND (damage <= 25))
);

CREATE TABLE human
(
    humanID      serial  NOT NULL PRIMARY KEY,
    speed        Integer NOT NULL CHECK ((speed >= 0) AND (speed <= 100)),
    health       Integer NOT NULL CHECK ((health >= 0) AND (health <= 100)),
    geolocation  Point   NOT NULL,
    money        Float NOT NULL CHECK ((money >= 0) AND (money <= 99999)),
    weaponID     Integer REFERENCES weapon_type (weaponID),
    name         Text,
    Surname      Text,
    Alias        Text    NOT NULL,
    is_slayed_by TEXT CHECK ((is_slayed_by like 'HUMAN') OR (is_slayed_by like 'MUTANT') OR
                             (is_slayed_by like 'ANOMALY')),
    slayerID     integer
);

CREATE TABLE groups_relations
(
    group_first_id  integer NOT NULL REFERENCES grouping (groupID) ON DELETE CASCADE,
    group_second_id integer NOT NULL REFERENCES grouping (groupID) ON DELETE CASCADE,
    PRIMARY KEY (group_first_id, group_second_id),
    relation        TEXT    NOT NULL CHECK ((relation like 'FRIENDS') OR (relation like 'ENEMIES') OR
                                            (relation = 'NEUTRAL'))
);

CREATE TABLE attitude
(
    groupID        integer NOT NULL REFERENCES grouping (groupID) ON DELETE CASCADE,
    humanID        integer NOT NULL REFERENCES human (humanID) ON DELETE CASCADE,
    PRIMARY KEY (groupID, humanID),
    loyality_level Float   NOT NULL CHECK ((loyality_level >= 0) AND (loyality_level <= 100))
);

CREATE TABLE stalker
(
    humanID    integer NOT NULL REFERENCES human (humanID) ON DELETE CASCADE,
    PRIMARY KEY (humanID),
    experience integer NOT NULL CHECK (experience >= 0),
    Biography  Text    NOT NULL
);

CREATE TABLE scientist
(
    humanID        integer NOT NULL REFERENCES human (humanID) ON DELETE CASCADE,
    PRIMARY KEY (humanID),
    Specialization Text    NOT NULL,
    Mission        Text    NOT NULL
);

CREATE TABLE warrior
(
    humanID        integer NOT NULL REFERENCES human (humanID) ON DELETE CASCADE,
    PRIMARY KEY (humanID),
    experience     integer NOT NULL CHECK (experience >= 0),
    mother_groupID integer NOT NULL REFERENCES grouping (groupID) ON DELETE CASCADE
);

CREATE TABLE trader
(
    humanID        integer NOT NULL REFERENCES human (humanID) ON DELETE CASCADE,
    PRIMARY KEY (humanID),
    mother_groupID integer NOT NULL REFERENCES grouping (groupID) ON DELETE CASCADE,
    customerID     integer REFERENCES human (humanID)
);

CREATE TABLE area
(
    areaID        serial      NOT NULL PRIMARY KEY,
    area_name     Text UNIQUE NOT NULL,
    geolocationLD Point       NOT NULL,
    geolocationRU Point       NOT NULL
);

CREATE TABLE anomaly
(
    anomalyID   serial  NOT NULL PRIMARY KEY,
-- artifactID Integer REFERENCES artifact(artifactID) ON DELETE CASCADE,
    artifactID  Integer,
    damage      Integer NOT NULL CHECK ((damage >= 15) AND (damage <= 25)),
    name        Text    NOT NULL,
    geolocation Point   NOT NULL,
    areaID      Integer REFERENCES area (areaID) ON DELETE CASCADE
);

CREATE TABLE artifact
(
    artifactID        serial  NOT NULL PRIMARY KEY,
    anomalyID         Integer REFERENCES anomaly (anomalyID) ON DELETE CASCADE,
    name              Text    NOT NULL,
    price             Integer NOT NULL CHECK ((price >= 0) AND (price <= 40000)),
    health_change     Integer NOT NULL CHECK ((health_change >= 0) AND (health_change <= 50)),
    speed_change      Integer NOT NULL CHECK ((speed_change >= 0) AND (speed_change <= 50)),
    spawn_probability Float   NOT NULL CHECK ((spawn_probability >= 0.0) AND (spawn_probability <= 100.0)),
    ownerID           Integer REFERENCES human (humanID) ON DELETE CASCADE
);

-- ALTER TABLE anomaly ADD artifactID INTEGER;
-- ALTER TABLE anomaly ADD CONSTRAINT fk_artifactID FOREIGN KEY (artifactID) REFERENCES artifact(artifactID) ON DELETE CASCADE;

CREATE TABLE area_group
(
    areaID  integer NOT NULL REFERENCES area (areaID) ON DELETE CASCADE,
    groupID integer NOT NULL REFERENCES grouping (groupID) ON DELETE CASCADE,
    PRIMARY KEY (areaID, groupID)
);

CREATE TABLE mutant
(
    mutantID    serial  NOT NULL PRIMARY KEY,
    health      Integer NOT NULL CHECK ((health >= 0) AND (health <= 100)),
    damage      Integer NOT NULL CHECK ((damage >= 5) AND (damage <= 15)),
    areaID      integer NOT NULL REFERENCES area (areaID),
    mutant_type text    NOT NULL CHECK (
            (mutant_type like 'DOG') OR
            (mutant_type like 'FLESH') OR
            (mutant_type like 'BLOODSUCKER') OR
            (mutant_type like 'SNORK') OR
            (mutant_type like 'CONTROLLER') OR
            (mutant_type like 'CHIMERA') OR
            (mutant_type like 'ZOMBIE')),
    geolocation Point   NOT NULL
);

CREATE TABLE shelter
(
    shelterID   serial  NOT NULL PRIMARY KEY,
    areaID      integer NOT NULL REFERENCES area (areaID),
    geolocation Point   NOT NULL
);

CREATE TABLE Route
(
    routeID           serial  NOT NULL PRIMARY KEY,
    start_geolocation Point   NOT NULL,
    final_geolocation Point   NOT NULL,
    start_pointID     Integer NOT NULL
);

CREATE TABLE route_points
(
    PointID      serial  NOT NULL PRIMARY KEY,
    RouteID      Integer NOT NULL REFERENCES route (routeID) ON DELETE CASCADE,
    geolocation  Point   NOT NULL,
    next_pointID Integer REFERENCES route_points (pointID)
);

CREATE TABLE human_route
(
    humanID integer NOT NULL REFERENCES human (humanID) ON DELETE CASCADE,
    routeID integer NOT NULL REFERENCES route (routeID) ON DELETE CASCADE,
    PRIMARY KEY (humanID, routeID)
);
