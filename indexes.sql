CREATE INDEX traderMOTHER ON trader(mother_groupid);
DROP INDEX traderMOTHER;

CREATE INDEX attitudeIndex ON attitude(loyality_level);
DROP INDEX attitudeIndex;

CREATE INDEX artifactName ON artifact(name);
DROP INDEX artifactName;
