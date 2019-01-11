#ifndef REG_H
#define REG_H

#define REG_WR(reg_name, wr_data)       (*((volatile uint32_t *)(0x00080000 | (reg_name))) = (wr_data))
#define REG_RD(reg_name)                (*((volatile uint32_t *)(0x00080000 | (reg_name))))

#endif
