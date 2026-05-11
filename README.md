# 🌐 ShareCo - Multiplatform Social E-commerce Application

<p align="center">
  <img src="assets/logo/shareco_new_logo_none_bg.png" alt="ShareCo Logo" width="180"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter Badge"/>
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart Badge"/>
  <img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase Badge"/>
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="Postgres Badge"/>
</p>

---

## 📝 Tổng Quan Dự Án (Project Overview)

**ShareCo** là một giải pháp ứng dụng thương mại điện tử đa nền tảng kết hợp mạng xã hội giải trí đột phá (mô hình **Social E-commerce** hay **Shoppertainment**). 

Dự án được xây dựng với mục tiêu mang lại trải nghiệm mua sắm thông minh, tương tác và liền mạch trên thiết bị di động cũng như trình duyệt web, giúp kết nối trực tiếp Người mua (Buyers), Đối tác nhãn hàng (Brands/Sellers), và Người sáng tạo nội dung (Creators).

> [!TIP]
> 🚀 **Mục tiêu cá nhân:** Dự án này là đồ án tốt nghiệp / đồ án môn học chuyên sâu, được thiết kế chuẩn chỉ về mặt kiến trúc phần mềm và cơ sở dữ liệu để phục vụ định hướng phỏng vấn thực tập sinh (Internship) và nhân viên chính thức (Junior/Fresher) của tôi.

---

## ✨ Các Tính Năng Nổi Bật (Key Features)

### 🛒 1. Phân Hệ Thương Mại Điện Tử (E-commerce Lifecycle)
* **Mua Sắm Toàn Diện:** Quản lý danh mục sản phẩm đa dạng, giỏ hàng động, quy trình checkout an toàn, thanh toán linh hoạt.
* **Đa Đối Tác (Multi-vendor):** Tách biệt giỏ hàng và xử lý đơn hàng theo từng nhãn hàng (L'Oreal, Cocoon, CeraVe...).
* **Hệ Thống Đánh Giá (Reviews):** Người dùng có thể đánh giá sản phẩm trực quan bằng điểm số và phản hồi.
* **Ưu Đãi & Mã Giảm Giá:** Tích hợp logic tính toán giảm giá sản phẩm tự động.

### 📱 2. Phân Hệ Mạng Xã Hội Giải Trí (Shoppertainment)
* **Video Feed ngắn:** Trải nghiệm xem video mượt mà, hỗ trợ thả tim, bình luận và chia sẻ (tương tự TikTok).
* **Gắn Nhãn Sản Phẩm (Product Tagging):** Xem video và mua hàng trực tiếp bằng cách bấm vào sản phẩm được gắn thẻ trong clip.
* **Hệ Thống Theo Dõi (Follow System):** Theo dõi nhãn hàng yêu thích và nhận thông tin cập nhật mới nhất.
* **Trò Chuyện Thời Gian Thực (Real-time Chat):** Chat trực tiếp giữa Khách hàng và Thương hiệu bằng kết nối thời gian thực Supabase.

### 👑 3. Phân Hệ Admin & Cổng Quản Trị Nhãn Hàng (Management Portals)
* **Cổng Super Admin:** Quản lý nhãn hàng, duyệt tài khoản đối tác, kiểm duyệt tất cả đơn hàng và phân tích thống kê toàn sàn.
* **Cổng Brand Owner (Nhà Bán Hàng):** Màn hình thống kê doanh số riêng, quản lý thông tin sản phẩm và quy trình đóng gói đơn hàng chuyên nghiệp.

---

## 🏛️ Kiến Trúc Hệ Thống & Công Nghệ (Tech Stack & Architecture)

### 💻 Front-End (Ứng dụng Di động & Web)
* **Ngôn ngữ:** **Dart**
* **Framework:** **Flutter** (Hỗ trợ build đa nền tảng đồng nhất Android, iOS, Web).
* **Quản Lý Trạng Thái (State Management):** **Flutter BLoC** (tách biệt hoàn toàn Business Logic khỏi UI, giúp mã nguồn dễ dàng mở rộng và kiểm thử).
* **Dependency Injection:** **GetIt** để tối ưu hóa quản lý Service Locator.
* **Thiết Kế:** **Clean Architecture** phân lớp chuẩn mực (Data, Domain, Presentation).

### ☁️ Back-End & Cơ Sở Dữ Liệu
* **Nền Tảng:** **Supabase BaaS** (Backend-as-a-Service).
* **Cơ Sở Dữ Liệu:** **PostgreSQL** với cấu trúc dữ liệu quan hệ chặt chẽ.
* **Bảo Mật Cơ Sở Dữ Liệu:** Áp dụng triệt để chính sách bảo mật dòng **Row-Level Security (RLS)** trên tất cả bảng nhạy cảm để kiểm soát quyền truy cập của người dùng và các nhãn hàng.
* **Database Triggers:** Sử dụng các function trigger để tự động đồng bộ số lượng lượt theo dõi, số lượng sản phẩm của cửa hàng, điểm đánh giá trung bình (rating_avg).
* **Lưu Trữ Hình Ảnh/Video:** Tích hợp **Cloudinary** để truyền tải đa phương tiện tốc độ cao.
* **Trí Tuệ Nhân Tạo:** Kết nối **OpenRouter AI** hỗ trợ tìm kiếm sản phẩm thông minh và đưa ra đề xuất cá nhân hóa.

---

## 📂 Sơ Đồ Cấu Trúc Thư Mục (Folder Structure)

Mã nguồn được cấu trúc theo tiêu chuẩn **Clean Architecture** kết hợp mô hình quản lý tính năng **Feature-First**:

```text
lib/
├── core/                       # Các tài nguyên dùng chung toàn app
│   ├── constants/              # Màu sắc, Kích thước, Assets
│   ├── network/                # Cấu hình kết nối Supabase, Http Client
│   ├── theme/                  # Định dạng phông chữ, chủ đề sáng/tối
│   └── utils/                  # Thư viện trợ giúp (Format tiền tệ, thời gian)
│
└── features/                   # Chứa các tính năng cốt lõi của dự án
    ├── auth/                   # Phân hệ Đăng nhập, Đăng ký
    ├── chat/                   # Phân hệ Nhắn tin Real-time
    ├── ecommerce/              # Phân hệ Cửa hàng, Giỏ hàng, Đơn hàng, Quản trị Admin
    │   ├── admin/              # Cổng Quản Trị Portal (Super Admin & Brand Owners)
    │   ├── cart/               # Giỏ hàng & Xử lý Thanh toán
    │   ├── order/              # Quy trình kiểm thử, cập nhật Đơn hàng
    │   └── shop/               # Hiển thị thông tin Gian hàng, Sản phẩm
    └── social/                 # Phân hệ Video ngắn, Hashtag, Tương tác mạng xã hội
```

---

## 🚀 Hướng Dẫn Cài Đặt Nhanh (Installation)

Dự án đã được cấu hình sẵn toàn bộ biến môi trường để bạn dễ dàng biên dịch và khởi chạy ngay lập tức. Chi tiết các bước cài đặt vui lòng xem tại:

👉 **[HƯỚNG DẪN CÀI ĐẶT & SỬ DỤNG DỰ ÁN](HUONG_DAN_CAI_DAT_VA_SU_DUNG.md)**

```bash
# 1. Tải toàn bộ thư viện về dự án
flutter pub get

# 2. Chạy ứng dụng trên thiết bị di động/giả lập của bạn
flutter run

# 3. Hoặc chạy trực tiếp trên trình duyệt Web (Chrome)
flutter run -d chrome
```

---

## 🔑 Tài Khoản Đăng Nhập Để Kiểm Thử (Demo Accounts)

Nhà tuyển dụng hoặc giảng viên có thể dùng các tài khoản kiểm thử sau đây để trải nghiệm ngay hệ thống mà không cần đăng ký tài khoản mới:

### 1. Tài khoản Super Admin
* **Email:** `admin@shareco.vn`
* **Mật khẩu:** `123456`
* **Quyền hạn:** Kiểm duyệt thương hiệu, mở khóa, xem doanh thu và thống kê toàn bộ hệ thống.

### 2. Tài khoản Đối Tác Nhãn Hàng (Brand Owners)
Sử dụng các tài khoản dưới đây để vào cổng quản lý gian hàng của riêng từng thương hiệu:

| Thương hiệu | Email Đăng Nhập | Mật khẩu | Quyền hạn kiểm thử |
| :--- | :--- | :--- | :--- |
| **L'Oreal** | `loreal@shareco.vn` | `123456` | Thêm sản phẩm, Đóng gói đơn của L'Oreal |
| **Cocoon** | `cocoon@shareco.vn` | `123456` | Thêm sản phẩm, Đóng gói đơn của Cocoon |
| **CeraVe** | `cerave@shareco.vn` | `123456` | Thêm sản phẩm, Đóng gói đơn của CeraVe |

---

## 🗄️ Cấu Trúc Cơ Sở Dữ Liệu (Database Schema)

Toàn bộ cấu trúc cơ sở dữ liệu của dự án đã được tôi **tối ưu hóa và gom gọn** duy nhất vào một tệp lệnh SQL chất lượng cao:
📂 **[database.sql](database.sql)**

Tệp này bao gồm toàn bộ:
* Định nghĩa bảng quan hệ (Tables Schema) cho Profiles, Carts, Orders, Videos, Shops...
* Dữ liệu mẫu hoàn chỉnh (Seed Data) các thương hiệu mỹ phẩm nổi tiếng cùng sản phẩm của chúng.
* Các Trigger Functions tự động đồng bộ điểm số và số lượng.
* Toàn bộ chính sách phân quyền dữ liệu dòng **Row-Level Security (RLS) Policies** cực kỳ bảo mật.

---

✉️ **Liên hệ và phản hồi:** Nếu bạn có bất kỳ câu hỏi nào liên quan đến kiến trúc dự án hoặc cơ hội hợp tác thực tập, vui lòng liên hệ với tôi qua Email hoặc số điện thoại của tôi. Cảm ơn bạn đã ghé thăm repository này!
