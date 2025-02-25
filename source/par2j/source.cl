void calc_table(__local uint *mtab, int id, int factor)
{
	int i, sum = 0;

	for (i = 0; i < 8; i++){
		sum = (id & (1 << i)) ? (sum ^ factor) : sum;
		factor = (factor & 0x8000) ? ((factor << 1) ^ 0x1100B) : (factor << 1);
	}
	mtab[id] = sum;

	sum = (sum << 4) ^ (((sum << 16) >> 31) & 0x88058) ^ (((sum << 17) >> 31) & 0x4402C) ^ (((sum << 18) >> 31) & 0x22016) ^ (((sum << 19) >> 31) & 0x1100B);
	sum = (sum << 4) ^ (((sum << 16) >> 31) & 0x88058) ^ (((sum << 17) >> 31) & 0x4402C) ^ (((sum << 18) >> 31) & 0x22016) ^ (((sum << 19) >> 31) & 0x1100B);

	mtab[id + 256] = sum;
}

__kernel void method1(
	__global uint *src,
	__global uint *dst,
	__global ushort *factors,
	int blk_num)
{
	__local uint mtab[512];
	int i, blk;
	uint v, sum;
	const int work_id = get_global_id(0);
	const int work_size = get_global_size(0);
	const int table_id = get_local_id(0);

	for (i = work_id; i < BLK_SIZE; i += work_size)
		dst[i] = 0;

	for (blk = 0; blk < blk_num; blk++){
		calc_table(mtab, table_id, factors[blk]);
		barrier(CLK_LOCAL_MEM_FENCE);

		for (i = work_id; i < BLK_SIZE; i += work_size){
			v = src[i];
			sum = mtab[(uchar)(v >> 16)] ^ mtab[256 + (v >> 24)];
			sum <<= 16;
			sum ^= mtab[(uchar)v] ^ mtab[256 + (uchar)(v >> 8)];
			dst[i] ^= sum;
		}
		src += BLK_SIZE;
		barrier(CLK_LOCAL_MEM_FENCE);
	}
}

__kernel void method2(
	__global uint *src,
	__global uint *dst,
	__global ushort *factors,
	int blk_num)
{
	__local uint mtab[512];
	int i, blk, pos;
	uint lo, hi, sum1, sum2;
	const int work_id = get_global_id(0) * 2;
	const int work_size = get_global_size(0) * 2;
	const int table_id = get_local_id(0);

	for (i = work_id; i < BLK_SIZE; i += work_size){
		dst[i    ] = 0;
		dst[i + 1] = 0;
	}

	for (blk = 0; blk < blk_num; blk++){
		calc_table(mtab, table_id, factors[blk]);
		barrier(CLK_LOCAL_MEM_FENCE);

		for (i = work_id; i < BLK_SIZE; i += work_size){
			pos = (i & ~7) + ((i & 7) >> 1);
			lo = src[pos    ];
			hi = src[pos + 4];
			sum1 = mtab[(uchar)(lo >> 16)] ^ mtab[256 + (uchar)(hi >> 16)];
			sum2 = mtab[lo >> 24] ^ mtab[256 + (hi >> 24)];
			sum1 <<= 16;
			sum2 <<= 16;
			sum1 ^= mtab[(uchar)lo] ^ mtab[256 + (uchar)hi];
			sum2 ^= mtab[(uchar)(lo >> 8)] ^ mtab[256 + (uchar)(hi >> 8)];
			dst[pos    ] ^= (sum1 & 0x00FF00FF) | ((sum2 & 0x00FF00FF) << 8);
			dst[pos + 4] ^= ((sum1 & 0xFF00FF00) >> 8) | (sum2 & 0xFF00FF00);
		}
		src += BLK_SIZE;
		barrier(CLK_LOCAL_MEM_FENCE);
	}
}

__kernel void method3(
	__global uint4 *src,
	__global uint4 *dst,
	__global ushort *factors,
	int blk_num)
{
	__local uint mtab[512];
	int i, blk;
	uchar4 r0, r1, r2, r3, r4, r5, r6, r7;
	uchar16 lo, hi;
	const int work_id = get_global_id(0) * 2;
	const int work_size = get_global_size(0) * 2;
	const int table_id = get_local_id(0);

	for (i = work_id; i < BLK_SIZE / 4; i += work_size){
		dst[i    ] = 0;
		dst[i + 1] = 0;
	}

	for (blk = 0; blk < blk_num; blk++){
		calc_table(mtab, table_id, factors[blk]);
		barrier(CLK_LOCAL_MEM_FENCE);

		for (i = work_id; i < BLK_SIZE / 4; i += work_size){
			lo = as_uchar16(src[i    ]);
			hi = as_uchar16(src[i + 1]);
			r0 = (uchar4)(as_uchar2((ushort)(mtab[lo.s0] ^ mtab[256 + hi.s0])), as_uchar2((ushort)(mtab[lo.s1] ^ mtab[256 + hi.s1])));
			r1 = (uchar4)(as_uchar2((ushort)(mtab[lo.s2] ^ mtab[256 + hi.s2])), as_uchar2((ushort)(mtab[lo.s3] ^ mtab[256 + hi.s3])));
			r2 = (uchar4)(as_uchar2((ushort)(mtab[lo.s4] ^ mtab[256 + hi.s4])), as_uchar2((ushort)(mtab[lo.s5] ^ mtab[256 + hi.s5])));
			r3 = (uchar4)(as_uchar2((ushort)(mtab[lo.s6] ^ mtab[256 + hi.s6])), as_uchar2((ushort)(mtab[lo.s7] ^ mtab[256 + hi.s7])));
			r4 = (uchar4)(as_uchar2((ushort)(mtab[lo.s8] ^ mtab[256 + hi.s8])), as_uchar2((ushort)(mtab[lo.s9] ^ mtab[256 + hi.s9])));
			r5 = (uchar4)(as_uchar2((ushort)(mtab[lo.sa] ^ mtab[256 + hi.sa])), as_uchar2((ushort)(mtab[lo.sb] ^ mtab[256 + hi.sb])));
			r6 = (uchar4)(as_uchar2((ushort)(mtab[lo.sc] ^ mtab[256 + hi.sc])), as_uchar2((ushort)(mtab[lo.sd] ^ mtab[256 + hi.sd])));
			r7 = (uchar4)(as_uchar2((ushort)(mtab[lo.se] ^ mtab[256 + hi.se])), as_uchar2((ushort)(mtab[lo.sf] ^ mtab[256 + hi.sf])));
			dst[i    ] ^= as_uint4((uchar16)(r0.x, r0.z, r1.x, r1.z, r2.x, r2.z, r3.x, r3.z, r4.x, r4.z, r5.x, r5.z, r6.x, r6.z, r7.x, r7.z));
			dst[i + 1] ^= as_uint4((uchar16)(r0.y, r0.w, r1.y, r1.w, r2.y, r2.w, r3.y, r3.w, r4.y, r4.w, r5.y, r5.w, r6.y, r6.w, r7.y, r7.w));
		}
		src += BLK_SIZE / 4;
		barrier(CLK_LOCAL_MEM_FENCE);
	}
}

__kernel void method4(
	__global uint *src,
	__global uint *dst,
	__global ushort *factors,
	int blk_num)
{
	__local int table[16];
	__local uint cache[256];
	int i, j, blk, pos, sht, mask;
	uint sum;
	const int work_id = get_global_id(0);
	const int work_size = get_global_size(0);

	for (i = work_id; i < BLK_SIZE; i += work_size)
		dst[i] = 0;

	for (blk = 0; blk < blk_num; blk++){
		if (get_local_id(0) == 0){
			pos = factors[blk] << 16;
			table[0] = pos;
			for (j = 1; j < 16; j++){
				pos = (pos << 1) ^ ((pos >> 31) & 0x100B0000);
				table[j] = pos;
			}
		}
		barrier(CLK_LOCAL_MEM_FENCE);

		for (i = work_id; i < BLK_SIZE; i += work_size){
			pos = i & 255;
			cache[pos] = src[i];
			barrier(CLK_LOCAL_MEM_FENCE);

			sum = 0;
			sht = (i & 60) >> 2;
			pos &= ~60;
			for (j = 15; j >= 0; j--){
				mask = (table[j] << sht) >> 31;
				sum ^= mask & cache[pos];
				pos += 4;
			}
			dst[i] ^= sum;
			barrier(CLK_LOCAL_MEM_FENCE);
		}
		src += BLK_SIZE;
	}
}
