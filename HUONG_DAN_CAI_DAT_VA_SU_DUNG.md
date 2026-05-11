# 🛠️ HƯỚNG DẪN CÀI ĐẶT VÀ SỬ DỤNG DỰ ÁN SHARECO

Tài liệu này hướng dẫn chi tiết các bước cài đặt, cấu hình môi trường và thông tin tài khoản dùng để đăng nhập, kiểm thử toàn bộ hệ thống ứng dụng **ShareCo** (Mạng xã hội & Thương mại điện tử).

---

## 📌 1. Yêu Cầu Hệ Thống & Công Cụ Chuẩn Bị

Trước khi bắt đầu, hãy đảm bảo máy tính của bạn đã được cài đặt đầy đủ các công cụ sau:

* **Flutter SDK:** Phiên bản `>= 3.10.4` (Khuyến nghị sử dụng bản Stable mới nhất).
* **Dart SDK:** Được đi kèm sẵn khi cài đặt Flutter.
* **IDE (Trình soạn thảo mã nguồn):** **VS Code** (khuyên dùng) hoặc **Android Studio** có cài đặt extension/plugin **Flutter** và **Dart**.
* **Thiết bị kiểm thử:**
  * Điện thoại thật (Android/iOS) đã bật chế độ nhà phát triển (Developer Mode) và gỡ lỗi USB (USB Debugging).
  * Hoặc máy ảo (Android Emulator / iOS Simulator).
  * Có thể chạy trực tiếp trên trình duyệt Web (Chrome/Edge) hoặc Windows Desktop.

---

## ⚙️ 2. Các Bước Cài Đặt Chi Tiết

### Bước 1: Mở thư mục dự án
Mở terminal hoặc cửa sổ Command Prompt/PowerShell tại thư mục gốc của dự án `shareco`:
```powershell
cd "d:\HK2 N3\cuoikydanentang\shareco"
```

### Bước 2: Kiểm tra cấu hình tệp môi trường `.env`
Dự án sử dụng tệp `.env` để cấu hình kết nối tới hệ sinh thái **Supabase (Backend)**, **OpenRouter (AI gợi ý)**, và **Cloudinary (Lưu trữ hình ảnh)**.

Tệp `.env` đã được cấu hình sẵn đầy đủ thông tin kết nối và đặt tại thư mục gốc dự án:
```env
SUPABASE_URL=https://pisjlqqwbogyypspdwse.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
OPENROUTER_API_KEY=sk-or-v1-b344314683...
CLOUDINARY_CLOUD_NAME=dd0j34fvy
CLOUDINARY_API_KEY=619295939964372
CLOUDINARY_API_SECRET=V8ie6DTJoSPrORRAzpz355i-8Jk
CLOUDINARY_UPLOAD_PRESET=ml_default
```

> [!NOTE]
> Bạn không cần thay đổi nội dung tệp này trừ khi muốn kết nối sang hệ thống cơ sở dữ liệu riêng của mình.

### Bước 3: Tải các gói thư viện (Dependencies)
Chạy lệnh sau tại thư mục gốc để tải và cập nhật toàn bộ thư viện cần thiết cho dự án:
```bash
flutter pub get
```

### Bước 4: Kiểm tra kết nối thiết bị
Đảm bảo thiết bị của bạn đã được kết nối và nhận diện bằng lệnh:
```bash
flutter devices
```

### Bước 5: Khởi chạy ứng dụng (Run App)
Chạy lệnh dưới đây để biên dịch và chạy ứng dụng trên thiết bị mặc định:
```bash
flutter run
```
*Để chạy trên nền tảng Web:*
```bash
flutter run -d chrome
```

---

## 🔑 3. Thông Tin Tài Khoản Đăng Nhập Hệ Thống

Để thuận tiện cho việc trình bày và kiểm thử, hệ thống đã chuẩn bị sẵn các bộ tài khoản với các quyền hạn phân tầng rõ rệt:

### 👑 A. Tài khoản Super Admin (Quản trị viên toàn hệ thống)
Sử dụng tài khoản này để vào **Admin Portal** quản lý chung tất cả thương hiệu, phê duyệt hoạt động, kiểm duyệt sản phẩm và theo dõi đơn hàng toàn sàn:

* **Email:** `admin@shareco.vn` (hoặc bất kỳ email nào có chứa chữ `"admin"`)
* **Mật khẩu:** `123456`

---

### 🏷️ B. Tài khoản Đối Tác Nhãn Hàng (Brand Owners)
Sử dụng các tài khoản dưới đây để đăng nhập vào giao diện dành riêng cho từng thương hiệu. Mỗi nhãn hàng chỉ được quyền thêm/sửa/xóa sản phẩm của chính mình và xử lý đóng gói các đơn hàng thuộc về thương hiệu của họ:

| Nhãn hàng / Thương hiệu | Email Đăng nhập | Mật khẩu | Chức năng kiểm thử chính |
| :--- | :--- | :--- | :--- |
| **L'Oreal** | `loreal@shareco.vn` | `123456` | Quản lý sản phẩm & Đơn đóng gói thương hiệu L'Oreal |
| **Cocoon** | `cocoon@shareco.vn` | `123456` | Quản lý sản phẩm & Đơn đóng gói thương hiệu Cocoon |
| **Anessa** | `anessa@shareco.vn` | `123456` | Quản lý sản phẩm & Đơn đóng gói thương hiệu Anessa |
| **CeraVe** | `cerave@shareco.vn` | `123456` | Quản lý sản phẩm & Đơn đóng gói thương hiệu CeraVe |
| **La Roche-Posay** | `laroche@shareco.vn` | `123456` | Quản lý sản phẩm & Đơn đóng gói thương hiệu La Roche-Posay |

> [!TIP]
> **Cơ chế Đăng ký tự động:** Nếu bạn đăng nhập bằng một email mới chưa có trong danh sách thương hiệu (ví dụ: `mac@shareco.vn`), hệ thống thông minh của ShareCo sẽ tự động nhận diện và hiển thị màn hình **Đăng ký Thương hiệu mới** để bạn có thể thêm mới một gian hàng đối tác ngay lập tức!

---

## ⚠️ 4. Một Số Lưu Ý Khi Chạy Dự Án

* **Đồng bộ hóa Database:** Hệ thống lưu trữ dữ liệu thời gian thực thông qua Supabase. Vui lòng giữ kết nối Internet ổn định trong lúc kiểm thử các tính năng mua hàng, nhắn tin thời gian thực và đăng video ngắn.
* **Lỗi biên dịch trên thiết bị:** Nếu gặp bất kỳ lỗi xung đột bộ nhớ cache nào trong quá trình build, hãy chạy lệnh dọn dẹp bộ nhớ:
  ```bash
  flutter clean
  ```
  Sau đó tải lại gói:
  ```bash
  flutter pub get
  ```
