
#include "global.h"
#include "i2c.h"
#include "reg.h"

#define UNUSED(x) (void)(x)

static int gLastScl;
static void i2c_set_scl(i2c_ctx_t *ctx, int bit)
{
   UNUSED(ctx);

   REG_WR(CODEC_SCL,bit);
   gLastScl = bit;
}

static void i2c_set_sda(i2c_ctx_t *ctx, int bit)
{
   UNUSED(ctx);

   REG_WR(CODEC_SDA,bit);
}


static int i2c_get_scl(i2c_ctx_t *ctx)
{
   UNUSED(ctx);

   return REG_RD(CODEC_SCL);
}

static int i2c_get_sda(i2c_ctx_t *ctx)
{
   int Ret = REG_RD(CODEC_SDA);
   UNUSED(ctx);

   REG_WR(LED_CONFIG, Ret != 0 ? 1 : 0);
   return Ret;
}

void i2c_init(i2c_ctx_t *ctx)
{
    UNUSED(ctx);

    i2c_set_sda(ctx, 1);
    i2c_set_scl(ctx, 1);
}


void i2c_dly()
{
    int i;
    for(i=0;i<10;++i){
       REG_WR(CODEC_SCL,gLastScl);
    }
}

void i2c_start(i2c_ctx_t *ctx)
{
    UNUSED(ctx);

    i2c_set_sda(ctx, 1);             // i2c start bit sequence
    i2c_dly();
    i2c_set_scl(ctx, 1);
    i2c_dly();
    i2c_set_sda(ctx, 0);
    i2c_dly();
    i2c_set_scl(ctx, 0);
    i2c_dly();
}

void i2c_stop(i2c_ctx_t *ctx)
{
    UNUSED(ctx);

    i2c_set_sda(ctx, 0);             // i2c stop bit sequence
    i2c_dly();
    i2c_set_scl(ctx, 1);
    i2c_dly();
    i2c_set_sda(ctx, 1);
    i2c_dly();
}

unsigned char i2c_rx(i2c_ctx_t *ctx, char ack)
{
    char x, d=0;
    UNUSED(ctx);

    i2c_set_sda(ctx, 1);

    for(x=0; x<8; x++) {
        d <<= 1;

        i2c_set_scl(ctx, 1);
        i2c_dly();
        // wait for any i2c_set_scl clock stretching
        while(i2c_get_scl(ctx)==0);

        d |= i2c_get_sda(ctx);
        i2c_set_scl(ctx, 0);
        i2c_dly();
    }
    if(ack)
        i2c_set_sda(ctx, 0);
    else
        i2c_set_sda(ctx, 1);

    i2c_set_scl(ctx, 1);
    i2c_dly();             // send (N)ACK bit

    i2c_set_scl(ctx, 0);
    i2c_dly();             // send (N)ACK bit

    i2c_set_sda(ctx, 1);
    return d;
}

// return 1: ACK, 0: NACK
int i2c_tx(i2c_ctx_t *ctx, unsigned char d)
{
    char x;
    int bit;
    UNUSED(ctx);

    for(x=8; x; x--) {
        i2c_set_sda(ctx, (d & 0x80)>>7);
        d <<= 1;
        i2c_dly();
        i2c_set_scl(ctx, 1);
        i2c_dly();
        i2c_set_scl(ctx, 0);
    }
    i2c_dly();
    i2c_set_sda(ctx, 1);
    i2c_dly();
    bit = i2c_get_sda(ctx);         // possible ACK bit
    i2c_set_scl(ctx, 1);
    i2c_dly();

#if 0
    if (bit){
        GPIO_DOUT_SET = 1;
    }
    else {
        GPIO_DOUT_CLR = 1;
    }
#endif

    i2c_set_scl(ctx, 0);
    i2c_dly();

    return !bit;
}

int i2c_write_buf(i2c_ctx_t *ctx, byte addr, byte* data, int len)
{
    int ack;
    UNUSED(ctx);

    i2c_start(ctx);
    ack = i2c_tx(ctx, addr);
    if (!ack){
        i2c_stop(ctx);
        return 0;
    }


    int i;
    for(i=0;i<len;++i){
        ack = i2c_tx(ctx, data[i]);
        if (!ack){
            i2c_stop(ctx);
            return 0;
        }
    }

    i2c_stop(ctx);

    return 1;
}

int i2c_read_buf(i2c_ctx_t *ctx, byte addr, byte *data, int len)
{
    int ack;
    UNUSED(ctx);

    i2c_start(ctx);

    ack = i2c_tx(ctx, addr | 1);
    if (!ack){
        i2c_stop(ctx);
        return 0;
    }

    int i;
    for(i=0;i<len;++i){
        data[i] = i2c_rx(ctx, i!=len-1);
    }
    i2c_stop(ctx);

    return 1;
}

int i2c_write_reg_nr(i2c_ctx_t *ctx, byte addr, byte reg_nr)
{
    return i2c_write_buf(ctx, addr, &reg_nr, 1);
}

int i2c_write_reg(i2c_ctx_t *ctx, byte addr, byte reg_nr, byte value)
{
    byte data[2] = { reg_nr, value };

    return i2c_write_buf(ctx, addr, data, 2);
}

int i2c_write_regs(i2c_ctx_t *ctx, byte addr, byte reg_nr, byte *values, int len)
{
    int ack;

    i2c_start(ctx);

    ack = i2c_tx(ctx, addr);
    if (!ack){
        i2c_stop(ctx);
        return 0;
    }

    ack = i2c_tx(ctx, reg_nr);
    if (!ack){
        i2c_stop(ctx);
        return 0;
    }

    int i;
    for(i=0;i<len;++i){
        ack = i2c_tx(ctx, values[i]);
        if (!ack){
            i2c_stop(ctx);
            return 0;
        }
    }

    i2c_stop(ctx);

    return 1;
}


int i2c_read_reg(i2c_ctx_t *ctx, byte addr, byte reg_nr, byte *value)
{
    int result;

    // Set address to read
    result = i2c_write_buf(ctx, addr, &reg_nr, 1);
    if (!result)
        return 0;

    result = i2c_read_buf(ctx, addr, value, 1);
    if (!result)
        return 0;

    return 1;
}

int i2c_read_regs(i2c_ctx_t *ctx, byte addr, byte reg_nr, byte *values, int len)
{
    int result;

    // Set address to read
    result = i2c_write_buf(ctx, addr, &reg_nr, 1);
    if (!result)
        return 0;

    result = i2c_read_buf(ctx, addr, values, len);
    if (!result)
        return 0;

    return 1;
}

