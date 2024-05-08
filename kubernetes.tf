# Создаем кластер кубернетес
resource "yandex_kubernetes_cluster" "kub-test" {
  # Указываем его имя
  name        = "kub-test"

  # Указываем, к какой сети он будет подключен
  network_id = yandex_vpc_network.internal.id

  # Указываем, что мастера располагаются в регионе ru-central и какие subnets использовать для каждой зоны
  master {
    regional {
      region = "ru-central1"

      location {
        zone      = yandex_vpc_subnet.internal-a.zone
        subnet_id = yandex_vpc_subnet.internal-a.id
      }

      location {
        zone      = yandex_vpc_subnet.internal-b.zone
        subnet_id = yandex_vpc_subnet.internal-b.id
      }

      location {
        zone      = yandex_vpc_subnet.internal-d.zone
        subnet_id = yandex_vpc_subnet.internal-d.id
      }
    }

    # Указываем версию Kubernetes
    version   = "1.29"
    # Назначаем внешний ip master нодам, чтобы мы могли подключаться к ним извне
    public_ip = true
  }

  # Указываем канал обновлений
  release_channel = "RAPID"
  # Указываем провайдера сетевых политик
  network_policy_provider = "CALICO"

  # Указываем сервисный аккаунт, который будут использовать ноды, и кластер для управления нодами
  node_service_account_id = yandex_iam_service_account.docker-registry.id
  service_account_id      = yandex_iam_service_account.instances-editor.id
}

# Создаем группу узлов
resource "yandex_kubernetes_node_group" "test-group-auto" {
  # Указываем, к какому кластеру они принадлежат
  cluster_id  = yandex_kubernetes_cluster.kub-test.id
  # Указываем название группы узлов
  name        = "test-group-auto"
  # И версию
  version     = "1.29"

  # Настраиваем шаблон виртуальной машины
  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat = true
      subnet_ids = [yandex_vpc_subnet.internal-a.id]
      /* subnet_ids = [yandex_vpc_subnet.internal-a.id, yandex_vpc_subnet.internal-b.id, yandex_vpc_subnet.internal-d.id] */
    }

    resources {
      core_fraction = 20 # Данный параметр позволяет уменьшить производительность CPU и сильно уменьшить затраты на инфраструктуру 
      memory        = 2
      cores         = 2
    }

    boot_disk {
      type = "network-hdd"
      size = 30
    }

    scheduling_policy {
      preemptible = false
    }
  }

  # Настраиваем политику масштабирования — в данном случае у нас группа фиксирована и в ней находятся 2 узла
  scale_policy {
    auto_scale {
      initial = 2
      min = 2
      max = 3
    }
  }

  # В каких зонах можно создавать машинки — указываем все зоны
  allocation_policy {
    location {
      zone = "ru-central1-a"
    }

    /* location { */
    /*   zone = "ru-central1-b" */
    /* } */

    /* location { */
    /*   zone = "ru-central1-d" */
    /* } */
  }

  # Отключаем автоматический апгрейд
  maintenance_policy {
    auto_upgrade = false
    auto_repair  = true
  }
}
