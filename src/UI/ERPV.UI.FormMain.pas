unit ERPV.UI.FormMain;

{
  Placeholder do form principal (T07 — esqueleto do projeto).

  Este form ainda não é o shell definitivo da aplicação: navegação, faixa de
  marca, status bar em 3 áreas e tema (AplicarTema/ConfigurarGrade/
  EstilizarBotao/Notificar) são responsabilidade de T14/T15/T68 (Lote 3),
  que substituem/completam este unit. Existe só para provar que o esqueleto
  do projeto (ERPVendas.dpr/.dproj, estrutura de pastas, unit scope
  ERPV.<Camada>.<Nome>) compila e abre uma janela, conforme o critério de
  aceite de T07.
}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs;

type
  TFormMain = class(TForm)
  private
    { Nenhuma regra de negócio, SQL ou chamada HTTP aqui — TASK.md Seção 1
      ("Forms finos"). }
  public
    { Public declarations }
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

end.
