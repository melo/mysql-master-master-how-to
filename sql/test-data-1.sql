INSERT INTO tig_users (uid, user_id) VALUES (1, 'user1');
INSERT INTO tig_users (uid, user_id) VALUES (2, 'user2');

INSERT INTO tig_nodes (nid, parent_nid, uid, node) VALUES (1, NULL, 1, 'node1');
INSERT INTO tig_nodes (nid, parent_nid, uid, node) VALUES (2, NULL, 2, 'node1');

INSERT INTO tig_pairs (nid, uid, pkey, pval) VALUES (1, 1, 'k1', 'v8');
INSERT INTO tig_pairs (nid, uid, pkey, pval) VALUES (1, 2, 'k2', 'v7');
INSERT INTO tig_pairs (nid, uid, pkey, pval) VALUES (1, 1, 'k3', 'v6');
INSERT INTO tig_pairs (nid, uid, pkey, pval) VALUES (1, 2, 'k4', 'v5');
INSERT INTO tig_pairs (nid, uid, pkey, pval) VALUES (2, 1, 'k5', 'v4');
INSERT INTO tig_pairs (nid, uid, pkey, pval) VALUES (2, 2, 'k6', 'v3');
INSERT INTO tig_pairs (nid, uid, pkey, pval) VALUES (2, 1, 'k7', 'v2');
INSERT INTO tig_pairs (nid, uid, pkey, pval) VALUES (2, 2, 'k8', 'v1');
