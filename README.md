# 🚀 Spring Boot vs WebAssembly (SpinKube) on MicroK8s

Bu proje, geleneksel bir **Java / Spring Boot** mikroservisi ile geleceğin teknolojisi olarak görülen **WebAssembly (Spin / Rust)** mimarisini yerel bir Kubernetes (MicroK8s) ortamında uçtan uca karşılaştırmak için hazırlanmış bir Proof of Concept (PoC) çalışmasıdır.

Amacımız: İki farklı mimarinin hızlarını (JIT vs Wasmtime) ve kaynak tüketimlerini (RAM & CPU) aynı şartlar altında test etmektir.

---

## 🏗️ Proje Mimarisi

Her iki uygulama da basit bir HTTP sunucusu olarak çalışır ve iki uç nokta (endpoint) sunar:
- `/hello`: Basit bir "Hello, World!" metni döner.
- `/compute`: Saf işlemci gücü test etmek amacıyla Fibonacci(35) hesabını rekürsif olarak yapar.

**Kullanılan Teknolojiler:**
- **Altyapı:** MicroK8s (CoreDNS ve yerel Registry aktif edilmiş haliyle)
- **Spring Boot (Java 21):** Uygulama `Jib Maven Plugin` ile Docker daemon'a ihtiyaç duyulmadan derlenip OCI imajı olarak MicroK8s'e aktarılmıştır.
- **SpinApp (Rust):** Fermyon Spin v3 ile Rust SDK kullanılarak yazılmış, `containerd-shim-spin-v2` motoru ve `Spin Operator v0.6.1` aracılığıyla K8s üzerinde çalıştırılan WASM modülü.

---

## 🛠️ Kurulum Adımları (Nasıl Denenir?)

Eğer bu deneyi kendi Ubuntu/MicroK8s ortamınızda yapmak isterseniz, repoda yer alan otomatik scriptleri kullanabilirsiniz.

### 1. Ön Hazırlık
Sisteminizde `microk8s`, `java 21`, `maven` ve `rust` kurulu olmalıdır. Eksik olan kurulumların çoğu (Java ve Rust dahil) script tarafından otomatik tamamlanır. Ancak Kubernetes yetkileri için komutları çalıştırırken `sudo` erişimine ihtiyacınız olacaktır.

### 2. Uygulamaları Derleme ve K8s'e Gönderme
Aşağıdaki ana dağıtım scripti; MicroK8s ayarlarını yapar, Spin Operator'ı Helm ile kurar, uygulamaları derleyip imaj deposuna (registry) gönderir ve Pod'ları ayağa kaldırır.

```bash
cd spin
./deploy.sh
```

**⚠️ Önemli (MicroK8s Containerd Düzeltmesi):**
MicroK8s, snap izolasyonu nedeniyle Spin motorunu varsayılan dizinlerde bulamaz. Eğer Spin pod'unuz `ContainerCreating` statüsünde takılı kalırsa, repo içindeki şu düzeltme scriptini çalıştırarak Wasm shim'ini (`containerd-shim-spin-v2`) doğru dizine indirebilirsiniz:
```bash
sudo ./fix-containerd.sh
```

---

## 🔥 Yük Testi (Load Testing)

Sistemdeki uygulamalara eşzamanlı yük bindirmek ve metrikleri arka planda yakalamak için repoda bulunan yük testi scriptini çalıştırın:

```bash
./load_test.sh
```
*Bu script, `apache2-utils` (ab) kullanarak her iki uygulamanın `/compute` (Fibonacci) endpoint'lerine 100 eşzamanlı bağlantı (`concurrency`) ile toplam 10.000 istek atacaktır.*

---

## 📊 Karşılaştırma Sonuçları ve Analiz

10.000 istekli yoğun yük testi (`ab`) sonucunda elde edilen veriler şunlardır:

### 1. Performans (Hız)
- **Spring Boot:** ~28 İstek/Saniye (Toplam süre: 352 saniye)
- **Spin (WASM):** ~18 İstek/Saniye (Toplam süre: 529 saniye)

*Analiz:* Yoğun CPU gerektiren (saf matematiksel hesaplama olan Fibonacci) sentetik testte Spring Boot'un (Java) daha hızlı çalıştığı görülmüştür. Bunun temel sebebi, Java'nın çalışma zamanında (Runtime) devreye giren JIT (Just-In-Time) derleyicisinin, sürekli tekrarlayan matematiksel döngüleri çok agresif bir şekilde optimize edebilmesidir. WebAssembly (Wasmtime) motoru henüz JIT seviyesinde bir optimizasyon sunmadığı için saf işlemci gücü gerektiren bu spesifik görevde geride kalmıştır.

### 2. Kaynak Tüketimi (CPU ve RAM)
- **Spring Boot:** Pik CPU: `3158m` (3.1 Core) | Pik RAM: `261Mi` (Boşta: ~130Mi)
- **Spin (WASM):** Pik CPU: `3129m` (3.1 Core) | Pik RAM: `87Mi` (Boşta: ~0Mi)

*Analiz:* Spin (WebAssembly) mimarisinin asıl parladığı nokta kaynak tüketimi olmuştur. Spring Boot boşta bile en az 130 MB bellek tüketirken, Spin boştayken ölçülemeyecek kadar az (neredeyse sıfır) kaynak tüketmektedir. En ağır yük altında bile Spin uygulaması sadece **87 MB** belleğe ihtiyaç duyarken, Spring Boot **261 MB** belleğe kadar çıkmıştır. 

### 3. Genel Değerlendirme ve Ölçeklenme Kazancı
Eğer sisteminizde yoğun matematiksel hesaplamalar yapılıyorsa JIT destekli diller (Java) avantajlıdır. Ancak bulut ortamlarında, WebAssembly (Spin) **"mikro saniyede ölçeklenme" (Scale to Zero / Scale to 10.000)** ve bunu yaparken faturanızı 10'da 1'ine düşürecek mikroskobik bellek tüketimi vaat eder.

1.000 Pod'luk bir Kubernetes yatay ölçeklenmesinde (HPA):
- **Spring Boot:** ~130 GB RAM maliyeti ve pod başına 3-5 saniyelik Cold Start.
- **Spin (WASM):** Sadece ~1 GB RAM maliyeti ve anlık (milisaniyelik) tepki süresi.

SpinKube ve WebAssembly ikilisi, Event-Driven (olay güdümlü) çalışan ve Serverless (Sunucusuz) mimarilerde koşan modern mikroservisler için endüstri standardı olma yolunda ilerlemektedir.
