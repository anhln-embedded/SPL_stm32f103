## Dự án STM32F103 — build & flash

Kho lưu trữ này chứa một dự án STM32F103 tối giản cùng với `makefile` đa nền tảng:

- Biên dịch mã nguồn trong thư mục `Src/`
- Bao gồm CMSIS / SPL nếu có trong `Libraries/`
- Đặt file đối tượng và sản phẩm build vào `build/`
- Sao chép `blinkled.elf` và `blinkled.bin` ra thư mục gốc sau khi build thành công

Yêu cầu

- Bộ công cụ GNU Arm: `arm-none-eabi-gcc`, `arm-none-eabi-objcopy`, `arm-none-eabi-objdump` đã có trong PATH
- `make` (GNU make)
- Để nạp chương trình: `openocd` (hoặc thay đổi target `flash` để dùng tool khác)

Build nhanh (PowerShell)

```
make clean
make -j4

# kết quả
dir build\
dir blinkled.*
```

Build nhanh (Unix)

```
make clean
make -j$(nproc)

# kết quả
ls -l build/
ls -l blinkled.*
```

Nạp chương trình (OpenOCD)

- Target `make flash` sử dụng OpenOCD với file `interface/stlink.cfg` + `target/stm32f1x.cfg`. Ví dụ:

```
make flash
```

Cấu hình

- Sửa đầu file `makefile` để thay đổi tối ưu hóa (`OPT`), cờ MCU, hoặc thêm đường dẫn include.
- Để ghi đè macro thiết bị mặc định, truyền biến `EXTRA_DEFS` khi chạy `make`. Ví dụ:

```
make EXTRA_DEFS="-DSTM32F10X_MD -DUSE_STDPERIPH_DRIVER"
```

Kết quả và cấu trúc thư mục

- `build/` — chứa tất cả file `.o` và `build/blinkled.elf` / `build/blinkled.bin`.
- Sau khi build, `blinkled.elf` và `blinkled.bin` cũng được copy ra thư mục gốc.

Khắc phục sự cố

- Nếu `make` báo lỗi thiếu header CMSIS hoặc SPL, kiểm tra lại thư mục vendor trong `Libraries/` hoặc đặt biến `CMSIS_DIR` / `SPL_DIR` khi chạy `make`.
- Nếu LED không nhấp nháy sau khi nạp: kiểm tra lại chân LED trên board (Blue Pill thường dùng `PC13`, Nucleo/Discovery có thể khác), và kiểm tra nguồn/cấu hình boot.

Kết thúc dòng

- Repo có file `.gitattributes` ép dùng LF cho mã nguồn. Nếu gặp cảnh báo LF/CRLF khi commit, chạy `git add --renormalize .` rồi commit lại.

Nếu bạn muốn, mình có thể thêm target `make release`, bước build static `libspl.a`, hoặc tách thư mục `build/obj` và `build/bin` — hãy cho mình biết bạn muốn gì nhé.
