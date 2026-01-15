### Key pairs
resource "aws_key_pair" "ssh-key" {
  key_name   = var.ssh_key_name
  public_key = var.ssh_public_key
}

# vim:filetype=terraform ts=2 sw=2 et: