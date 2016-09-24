module sect_dist;

import std.random : uniform;
import gl3n.linalg;

alias pos_val = float;
alias pos_val_int = int;
pragma(inline, true):
/* help for non-sse program */
pos_val_int ss2i(pos_val ss) {
    return *cast(pos_val_int*)&ss;
}

pos_val i2ss(pos_val_int i) {
    return *cast(pos_val*)&i;
}

pos_val and_ss(pos_val s1, pos_val s2) {
    return i2ss(ss2i(s1) & ss2i(s2));
}

pos_val xor_ss(pos_val s1, pos_val s2) {
    return i2ss(ss2i(s1) ^ ss2i(s2));
}

pos_val or_ss(pos_val s1, pos_val s2) {
    return i2ss(ss2i(s1) | ss2i(s2));
}

pos_val inv_ss(pos_val s) {
    return i2ss(~ss2i(s));
}

pos_val cmpgt_ss(pos_val s1, pos_val s2) {
    return (s1 > s2) ? i2ss(~cast(pos_val_int) 0) : i2ss(0);
}

pos_val cmplt_ss(pos_val s1, pos_val s2) {
    return (s1 < s2) ? i2ss(~cast(pos_val_int) 0) : i2ss(0);
}

pos_val rev_ss(pos_val s) {
    return 1.0f / s;
}

pos_val min_ss(pos_val s1, pos_val s2) {
    return (s1 < s2) ? s1 : s2;
}

auto sgn_bit() {
    return i2ss((cast(pos_val_int) 0x1) << (pos_val_int.sizeof * 8 - 1));
}

auto inf_mask() {
    return i2ss((cast(pos_val_int) 0xFF) << (pos_val_int.sizeof * 8 - 9));
}

auto sgn_mask() {
    return i2ss((cast(pos_val_int) 0x1FF) << (pos_val_int.sizeof * 8 - 9));
}

//#define sgn_bit i2ss(((pos_val_int)0x1)<<(sizeof(pos_val_int)*8-1))
//#define inf_mask i2ss(((pos_val_int)0xFF)<<(sizeof(pos_val_int)*8-9))
//#define sgn_mask i2ss(((pos_val_int)0x1FF)<<(sizeof(pos_val_int)*8-9))

//vec2 don't have mulv so add it 
pos_val mulv(pos_t a, pos_t p) {
    return a.x * p.y - a.y * p.x;
}

alias pos_t = vec2;

struct sect {
    pos_t A, B;
    pos_t v() {
        return B - A;
    }
}

pragma(inline):
pos_val[2] sect_dist_spd(sect s1, sect s2) {
    pos_t v1 = s1.v();
    pos_t va1a2 = s2.A - s1.A;
    pos_t va1b2 = s2.B - s1.A;
    pos_t vb1a2 = s2.A - s1.B;
    pos_t vb1b2 = s2.B - s1.B;
    pos_val l1_quad = v1.length_squared();
    pos_val m1 = v1 * va1a2;
    pos_val m2 = v1 * va1b2;
    pos_val r1 = and_ss(m1, m2);
    pos_val r2 = and_ss(l1_quad - m1, l1_quad - m2);
    pos_val r = and_ss(inv_ss(or_ss(r1, r2)), sgn_bit);
    pos_val min_quad_dist = min_ss(min_ss(va1a2.length_squared(), va1b2.length_squared()),
        min_ss(vb1a2.length_squared(), vb1b2.length_squared()));
    return [min_quad_dist, r];
}
///first return value is distance beetween lines, second is zero if they are colliding
pos_val[2] sect_dist_nxt(sect s1, sect s2, pos_val prev_ret) {
    pos_t v1 = s1.v();
    pos_t v2 = s2.v();
    pos_t va1a2 = s2.A - s1.A;
    pos_t va1b2 = s2.B - s1.A;
    pos_t va2a1 = s1.A - s2.A;
    pos_t va2b1 = s1.B - s2.A;

    pos_val l1_quad = v1.length_squared();
    pos_val m1 = v1 * va1a2;
    pos_val m2 = v1 * va1b2;
    pos_val c1 = and_ss(cmplt_ss(and_ss(or_ss(m1, l1_quad - m1), sgn_mask), 0), inf_mask);
    pos_val c2 = and_ss(cmplt_ss(and_ss(or_ss(m2, l1_quad - m2), sgn_mask), 0), inf_mask);

    pos_val l2_quad = v2.length_squared();
    pos_val m3 = v2 * va2a1;
    pos_val m4 = v2 * va2b1;
    pos_val c3 = and_ss(cmplt_ss(and_ss(or_ss(m3, l2_quad - m3), sgn_mask), 0), inf_mask);
    pos_val c4 = and_ss(cmplt_ss(and_ss(or_ss(m4, l2_quad - m4), sgn_mask), 0), inf_mask);

    pos_val __rl1_quad = rev_ss(l1_quad);
    pos_val __rl2_quad = rev_ss(l2_quad);

    pos_val v1ma = v1.mulv(va1a2);
    pos_val v1mb = v1.mulv(va1b2);
    pos_val v2ma = v2.mulv(va2a1);
    pos_val v2mb = v2.mulv(va2b1);

    pos_val r1 = xor_ss(v1ma, v1mb);
    pos_val r2 = xor_ss(v2ma, v2mb);
    pos_val rr = and_ss(and_ss(r1, r2), sgn_bit);

    pos_val d1 = v1ma + c1;
    d1 = d1 * d1 * __rl1_quad;
    pos_val d2 = v1mb + c2;
    d2 = d2 * d2 * __rl1_quad;
    pos_val d3 = v2ma + c3;
    d3 = d3 * d3 * __rl2_quad;
    pos_val d4 = v2mb + c4;
    d4 = d4 * d4 * __rl2_quad;

    pos_val dd = min_ss(min_ss(d1, d2), min_ss(d3, d4));

    return [min_ss(prev_ret, dd), rr];
}
unittest {
	sect[2][] sectsToCollide = [
		[sect(pos_t(0, -10), pos_t(0, 10)), sect(pos_t(-10, 0), pos_t(10, 0))],
	];
	sect[2][] sectsNotToCollide = [
		[sect(pos_t(0, -10), pos_t(0, -5)), sect(pos_t(-10, 0), pos_t(10, 0))],
		[sect(pos_t(0, -10), pos_t(0, -5)), sect(pos_t(4, -10), pos_t(4, -5))],
		[sect(pos_t(0, 10), pos_t(0, 5)), sect(pos_t(0, 3), pos_t(0, 1))],
	];
	
	foreach (i, sects;sectsToCollide) {
		float qLength=sect_dist_nxt( sects[0], sects[1], 100)[0];
	//	assert(qLength<0.0001);
	}
	foreach (i, sects;sectsNotToCollide) {
		float qLength=sect_dist_nxt( sects[0], sects[1], 100)[0];
	//	assert(qLength>0.0001);
	}
}
