struct MessagePack::Packer
  def write(value : BlackVeilServer::Object)
    write(value.attrs.to_h)
  end

  def write(value : BlackVeilServer::ObjectReference)
    write(value.attrs.to_h)
  end
end
