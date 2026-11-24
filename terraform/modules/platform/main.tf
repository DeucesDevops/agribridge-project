locals {
  values_dir = "${path.module}/values"

  chart_version = {
    external_secrets = "2.15.0"
    external_dns     = "1.23.0"
    loki             = "7.6.0"
    monitoring       = "93.3.1"
    promtail         = "6.17.1"
    # Keep the CI helm template version in .github/workflows/cicd.yaml in step with this.
    argocd = "10.18.2"
  }

  argocd_values = {
    global = {
      domain = var.argocd_hostname
    }
    configs = {
      cm = {
        url = "https://${var.argocd_hostname}"
      }
    }
    server = {
      ingress = {
        hostname = var.argocd_hostname
        annotations = {
          "alb.ingress.kubernetes.io/certificate-arn" = var.certificate_arn
          "external-dns.alpha.kubernetes.io/hostname" = var.argocd_hostname
        }
      }
    }
  }

  storage_class = yamldecode(file("${local.values_dir}/storage-class.yaml"))

  grafana_values = {
    grafana = {
      "grafana.ini" = {
        server = {
          root_url = "https://${var.grafana_hostname}"
        }
        users = {
          allow_sign_up = false
        }
        "auth.anonymous" = {
          enabled = false
        }
      }
      # Calico pod IPs are not routable from the VPC, so the ALB targets the
      # node port (same as the app ingress) instead of pod IPs.
      service = {
        type = "NodePort"
      }
      ingress = {
        enabled          = true
        ingressClassName = "alb"
        path             = "/"
        pathType         = "Prefix"
        hosts            = [var.grafana_hostname]
        annotations = {
          "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"      = "instance"
          "alb.ingress.kubernetes.io/group.name"       = "agribridge"
          "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80},{\"HTTPS\":443}]"
          "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
          "alb.ingress.kubernetes.io/certificate-arn"  = var.certificate_arn
          "alb.ingress.kubernetes.io/healthcheck-path" = "/api/health"
          "alb.ingress.kubernetes.io/success-codes"    = "200"
          "external-dns.alpha.kubernetes.io/hostname"  = var.grafana_hostname
        }
      }
    }
  }
}
